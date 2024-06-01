import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gamescreen.dart'; 

class GamePage extends StatefulWidget {
  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  String? _selectedGameType;
  String? _selectedLetterCount;
  bool isUserJoined = false;
  String? gameCollection;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Game Settings and Invitations'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            if (currentUser != null) ...[
              _buildGameSettings(),
              _buildChannelParticipants(),
              _buildOutgoingInvitations(),
              _buildIncomingInvitations(),
              _listenAcceptedInvitations(),
            ] else ...[
              Center(child: Text("Please log in to continue.")),
            ],
          ],
        ),
      ),
    );
  }

  Widget _listenAcceptedInvitations() {
    if (gameCollection == null) return SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Invitations')
          .where('gameId', isEqualTo: gameCollection)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active &&
            snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            if (doc['inviterId'] == currentUser!.uid ||
                doc['inviteeId'] == currentUser!.uid) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            GameScreen(channelId: gameCollection!)));
              });
              break;
            }
          }
        }
        return SizedBox.shrink();
      },
    );
  }

  Widget _buildGameSettings() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          hint: Text('Select Game Type'),
          value: _selectedGameType,
          items: ['Type I', 'Type II'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedGameType = newValue;
              updateGameCollection();
            });
          },
        ),
        DropdownButtonFormField<String>(
          hint: Text('Select Letter Count'),
          value: _selectedLetterCount,
          items: ['5', '6'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedLetterCount = newValue;
              updateGameCollection();
            });
          },
        ),
        ElevatedButton(
          onPressed: joinChannel,
          child: Text('Join Game Channel'),
        ),
        if (isUserJoined)
          Text("You have joined the game! Waiting for players..."),
      ],
    );
  }

  void updateGameCollection() {
    if (_selectedGameType != null && _selectedLetterCount != null) {
      gameCollection = 'DB$_selectedLetterCount$_selectedGameType';
    }
  }

  Widget _buildChannelParticipants() {
    if (!isUserJoined || gameCollection == null) return SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection(gameCollection!).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return Text("No participants in this channel.");

        return ListView.builder(
          shrinkWrap: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var userId = docs[index]['userId'];
            return ListTile(
              title: Text(userId),
              trailing: currentUser!.uid != userId
                  ? ElevatedButton(
                      onPressed: () => sendInvitation(userId),
                      child: Text('Invite'),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Future<void> sendInvitation(String inviteeId) async {
    if (currentUser != null && gameCollection != null) {
      try {
        await FirebaseFirestore.instance.collection('Invitations').add({
          'inviterId': currentUser!.uid,
          'inviteeId': inviteeId,
          'gameId': gameCollection!,
          'status': 'pending',
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation sent to $inviteeId')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invitation: $e')),
        );
      }
    }
  }

  Widget _buildOutgoingInvitations() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Invitations')
          .where('inviterId', isEqualTo: currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return Text("No outgoing invitations.");

        return ListView.builder(
          shrinkWrap: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text('Invitation sent to ${docs[index]['inviteeId']}'),
              subtitle: Text('Status: ${docs[index]['status']}'),
            );
          },
        );
      },
    );
  }

  Widget _buildIncomingInvitations() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Invitations')
          .where('inviteeId', isEqualTo: currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return Text("No incoming invitations.");

        return ListView.builder(
          shrinkWrap: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            return ListTile(
              title: Text('${doc['inviterId']} invited you'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () => acceptInvitation(
                        doc.id, doc['inviterId'], currentUser!.uid, context),
                    child: Text('Accept'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => rejectInvitation(doc.id, context),
                    child: Text('Reject'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void joinChannel() async {
    if (_selectedGameType != null &&
        _selectedLetterCount != null &&
        currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection(gameCollection!)
            .doc(currentUser!.uid)
            .set({
          'userId': currentUser!.uid,
        });
        setState(() {
          isUserJoined = true;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join channel: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Please select game type and letter count before joining.')),
      );
    }
  }

  Future<void> acceptInvitation(String invitationId, String inviterId,
      String inviteeId, BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('Invitations')
        .doc(invitationId)
        .update({'status': 'accepted'});
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => GameScreen(channelId: gameCollection!)));
  }

  Future<void> rejectInvitation(
      String invitationId, BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('Invitations')
        .doc(invitationId)
        .update({'status': 'rejected'});
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Invitation rejected")));
  }
}