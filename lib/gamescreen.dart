import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_page.dart'; 

class GameScreen extends StatefulWidget {
  final String channelId;

  GameScreen({required this.channelId});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late String userId;

  String hedefKelime = ""; 
  String tahminKelime =
      ""; 
  List<Color> kutucukRenkleri = []; 
  int kalanTahminHakki =
      5; 
  bool tamamlandi = false;
  int score = 0;

  final TextEditingController wordController = TextEditingController();

  late Stream<String> wordStream;

  @override
  void initState() {
    super.initState();

    User? user = FirebaseAuth.instance.currentUser;
    userId = user?.uid ?? "Unknown"; 

    createGameDocument(userId, widget.channelId);

    wordStream = FirebaseFirestore.instance
        .collection('games')
        .doc(widget.channelId)
        .collection('players')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot['word'] ?? '');

    wordStream.listen((word) {
      setState(() {
        hedefKelime = word.toUpperCase();
        kutucukRenkleri
            .clear(); 
        for (int i = 0; i < hedefKelime.length; i++) {
          kutucukRenkleri.add(Color.fromARGB(255, 211, 211, 211));
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Game Screen'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Welcome to the game! User ID: $userId Channel ID: ${widget.channelId}',
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: wordController,
              decoration: InputDecoration(labelText: 'Enter a word'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: submitWord,
              child: Text('Submit Word'),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              children: [
                SizedBox(height: 20.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < hedefKelime.length; i++)
                      Container(
                        width: 40.0,
                        height: 40.0,
                        margin: EdgeInsets.symmetric(horizontal: 5.0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: kutucukRenkleri.length > i
                              ? kutucukRenkleri[i]
                              : Color.fromARGB(255, 156, 152, 152),
                          borderRadius: BorderRadius.circular(5.0),
                        ),
                        child: Text(
                          tahminKelime.length > i ? tahminKelime[i] : '',
                          style: TextStyle(fontSize: 20.0, color: Colors.black),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 20.0),
                Text(
                  'Kalan Tahmin Hakkı: $kalanTahminHakki',
                  style: TextStyle(fontSize: 18.0),
                ),
                SizedBox(height: 20.0),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      tahminKelime = value.toUpperCase();
                    });
                  },
                  onSubmitted: (value) {
                    tahminKontrol();
                    if (!tamamlandi) {
                      tahminKelime = value.toUpperCase();
                    } else {
                      score *= kalanTahminHakki;
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Oyun Bitti'),
                          content: Text('Skorunuz: $score'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        GamePage(), 
                                  ),
                                );
                              },
                              child: Text('Tamam'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  maxLength: hedefKelime.isEmpty ? null : hedefKelime.length,
                  decoration: InputDecoration(
                    hintText: 'Kelimeyi tahmin edin',
                    border: OutlineInputBorder(),
                  ),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  style: TextStyle(fontSize: 18.0),
                ),
                SizedBox(height: 20.0),
                StreamBuilder<String>(
                  stream: wordStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }
                    return Text(
                      'nocopyright',
                      style: TextStyle(fontSize: 12.0),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> createGameDocument(String userId, String channelId) async {
    try {
      await FirebaseFirestore.instance
          .collection('games')
          .doc(channelId) 
          .collection('players')
          .doc(userId) 
          .set({
        'userId': userId,
      });
      print('Game document created successfully!');
    } catch (e) {
      print('Error creating game document: $e');
    }
  }

  Future<void> submitWord() async {
    String word = wordController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a word")),
      );
      return;
    }

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.channelId)
          .collection('players')
          .get();

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        if (doc.id != userId) {
          await FirebaseFirestore.instance
              .collection('games')
              .doc(widget.channelId)
              .collection('players')
              .doc(doc.id)
              .update({'word': word});
        }
      }
    } catch (e) {
      print('Error submitting word: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting word")),
      );
    }
  }

  void tahminKontrol() {
    setState(() {
      kalanTahminHakki--;
      if (kalanTahminHakki <= 0) {
        tamamlandi = true;
      }
      for (int i = 0; i < hedefKelime.length; i++) {
        if (hedefKelime[i] == tahminKelime[i]) {
          kutucukRenkleri[i] = Colors.green; 
          score += 10;
        } else if (hedefKelime.contains(tahminKelime[i])) {
          kutucukRenkleri[i] = Colors.yellow; 
          score += 5;
        } else {
          kutucukRenkleri[i] = Colors.red; 
        }
      }
      if (kutucukRenkleri.every((color) => color == Colors.green)) {
        tamamlandi = true;
      }
    });
  }
}