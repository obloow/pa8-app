import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pa8/models/Analyse.dart';
import 'package:pa8/models/User.dart';
import 'package:pa8/models/references/UserType.dart';
import 'package:pa8/routes/routes.dart';
import 'package:pa8/screens/analyse/local/analyseMaker.dart';
import 'package:pa8/screens/home/widgets/lastAnalysesWidget.dart';
import 'package:pa8/screens/home/widgets/reminderWidget.dart';
import 'package:pa8/screens/patient/patientScreen.dart';
import 'package:pa8/services/AuthenticationService.dart';
import 'package:pa8/services/DatabaseService.dart';
import 'package:pa8/widgets/Loading.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/homeScreen';

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ImagePicker _picker;
  bool loading;

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
    loading = false;
  }

  @override
  Widget build(BuildContext _context) {
    UserData user = Provider.of<UserData>(context);
    if (loading) {
      return LoadingScaffold();
    }

    if (user == null) {
      return _userNotConnected();
    }

    if (user.userType == UserType.CLIENT) {
      return _userConnected(user);
    }

    if (user.userType == UserType.DOCTOR) {
      return _doctor(user);
    }
    //AuthenticationService.signOut();
    return Scaffold();
  }

  Widget _userNotConnected() {
    return FutureBuilder(
      future: DatabaseService(userUid: "").analysesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          List<Analyse> analyses = snapshot.data;
          return _homeScaffold(null, analyses);
        } else {
          return LoadingScaffold();
        }
      },
    );
  }

  Widget _userConnected(UserData user) {
    return StreamBuilder(
      stream: DatabaseService(userUid: user.uid).analysesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          List<Analyse> analyses = snapshot.data;
          return _homeScaffold(user, analyses);
        } else {
          return LoadingScaffold();
        }
      },
    );
  }

  Widget _doctor(UserData user) {
    final _formKey = GlobalKey<FormState>();
    String code;
    return Scaffold(
      appBar: _appBar(user),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Card(
              elevation: 5,
              child: Container(
                margin: EdgeInsets.all(5),
                child: Form(
                  key: _formKey,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Container(
                        width: 200,
                        margin: EdgeInsets.only(bottom: 5),
                        child: TextFormField(
                          decoration: const InputDecoration(
                            icon: Icon(Icons.person_add),
                            hintText: 'Code client',
                            labelText: 'Code',
                          ),
                          onChanged: (value) {
                            code = value;
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Entrez un code';
                            }
                            return null;
                          },
                        ),
                      ),
                      ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState.validate()) {
                              List<UserData> users = await DatabaseService(userUid: user.uid).listUserDataFuture;
                              bool found = false;
                              users.forEach((element) async {
                                if (element.code == code) {
                                  if (user.patientUids == null) {
                                    user.patientUids = [element.uid];
                                  } else {
                                    user.patientUids.add(element.uid);
                                  }
                                  await DatabaseService(userUid: user.uid).updateUserData(user);
                                  found = true;
                                }
                              });
                              if (found) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Patient ajouté !')));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ce code n'est pas associé !")));
                              }
                            }
                          },
                          child: Text("Ajouter"))
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(
            indent: 15,
            endIndent: 15,
          ),
          if (user.patientUids != null)
            Container(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: user.patientUids.length,
                itemBuilder: (context, index) {
                  String patientUid = user.patientUids[index];
                  return StreamBuilder(
                    stream: DatabaseService(userUid: patientUid).userDataStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.active) {
                        UserData patient = snapshot.data;
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) => PatientScreen(user: user, patient: patient)));
                          },
                          child: Container(
                            margin: EdgeInsets.all(5),
                            child: Card(
                              elevation: 3,
                              child: ListTile(
                                leading: Container(
                                  margin: EdgeInsets.all(10),
                                  child: Image.network(patient.profilePicture),
                                ),
                                title: Text(patient.userName),
                              ),
                            ),
                          ),
                        );
                      } else {
                        return LoadingWidget();
                      }
                    },
                  );
                },
              ),
            )
        ],
      ),
    );
  }

  Widget _homeScaffold(UserData user, List<Analyse> analyses) {
    return Scaffold(
      appBar: _appBar(user),
      body: Column(
        children: [
          ReminderWidget(user, analyses, _picker),
          LastAnalysesWidget(user, analyses),
        ],
      ),
      floatingActionButton: _floatingAnalyseButton(user),
    );
  }

  Widget _actionAppBar(UserData user) {
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.person_add),
        tooltip: 'Se connecter',
        onPressed: () async {
          await AuthenticationService.signInWithGoogle();
        },
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.person),
        tooltip: 'Mon profile',
        onPressed: () async {
          Navigator.pushNamed(context, Routes.profile);
        },
      );
    }
  }

  Widget _floatingAnalyseButton(UserData user) {
    return FloatingActionButton(
      onPressed: () async {
        setState(() {
          loading = true;
        });
        final pickedFile = await _picker.getImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_context) => AnalyseMaker(
                        user: user,
                        image: File(pickedFile.path),
                      )));
        }
        setState(() {
          loading = false;
        });
      },
      child: Icon(Icons.camera_alt),
      backgroundColor: Colors.blue,
    );
  }

  Widget _appBar(UserData user) {
    return AppBar(
      title: user == null ? Text("POTECT") : Text(user.userName),
      centerTitle: true,
      actions: <Widget>[_actionAppBar(user)],
    );
  }
}
