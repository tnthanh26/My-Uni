import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_uni/utils/poll_utils.dart';

class PollWidget extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> pollData;
  final String collectionPath;

  const PollWidget({
    super.key,
    required this.docId,
    required this.pollData,
    this.collectionPath = 'forum_posts',
  });

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isVoting = false;
  
  // Local state for Optimistic UI
  Map<String, dynamic>? _localVotes;

  Future<void> _vote(int optionIndex, Map<String, dynamic> currentPollData) async {
    if (_currentUserId == null || _isVoting) return;

    // 1. Prepare new vote state optimistically
    final Map<String, dynamic> serverVotes = Map<String, dynamic>.from(currentPollData['votes'] ?? {});
    final Map<String, dynamic> votes = Map<String, dynamic>.from(_localVotes ?? serverVotes);
    
    dynamic rawUserVote = votes[_currentUserId];
    List<int> userVotes = [];
    if (rawUserVote is List) {
      userVotes = List<int>.from(rawUserVote);
    } else if (rawUserVote is int) {
      userVotes = [rawUserVote];
    }

    if (userVotes.contains(optionIndex)) {
      userVotes.remove(optionIndex);
    } else {
      userVotes.add(optionIndex);
    }

    setState(() {
      _localVotes = {...votes, _currentUserId!: userVotes};
      _isVoting = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.docId)
          .update({
        'poll.votes.$_currentUserId': userVotes,
      });
    } catch (e) {
      // Revert optimistic update on error
      setState(() => _localVotes = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi bình chọn: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(widget.docId)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> currentPollData = widget.pollData;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          if (data['poll'] != null) {
            currentPollData = data['poll'];
            // Sync local state if we are not actively voting
            if (!_isVoting) {
              _localVotes = Map<String, dynamic>.from(currentPollData['votes'] ?? {});
            }
          }
        }

        final List<dynamic> options = currentPollData['options'] ?? [];
        final Map<String, dynamic> votes = _localVotes ?? Map<String, dynamic>.from(currentPollData['votes'] ?? {});
        final int totalParticipants = votes.length;
        
        dynamic rawUserVote = votes[_currentUserId];
        List<int> currentUserVotes = [];
        if (rawUserVote is List) {
          currentUserVotes = List<int>.from(rawUserVote);
        } else if (rawUserVote is int) {
          currentUserVotes = [rawUserVote];
        }
        
        final bool hasVoted = currentUserVotes.isNotEmpty;
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        Map<int, int> optionCounts = {};
        for (var v in votes.values) {
          if (v is List) {
            for (var idx in v) {
              if (idx is int) optionCounts[idx] = (optionCounts[idx] ?? 0) + 1;
            }
          } else if (v is int) {
            optionCounts[v] = (optionCounts[v] ?? 0) + 1;
          }
        }

        int totalVotes = 0;
        optionCounts.forEach((key, value) => totalVotes += value);

        List<int> counts = options.asMap().keys.map((idx) => optionCounts[idx] ?? 0).toList();
        List<int> percentages = PollUtils.calculatePercentages(counts);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E2228) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDarkMode 
              ? [] 
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
            border: Border.all(color: isDarkMode ? Colors.white10 : const Color(0xFFEDF2F7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF306CFE).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.poll_rounded, size: 18, color: Color(0xFF306CFE)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Khảo sát ý kiến",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : const Color(0xFF2D3748),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...options.asMap().entries.map((entry) {
                int idx = entry.key;
                String text = entry.value.toString();
                int percentageValue = percentages[idx];
                double percentageFactor = totalVotes > 0 ? (optionCounts[idx] ?? 0) / totalVotes : 0.0;
                bool isSelected = currentUserVotes.contains(idx);

                return GestureDetector(
                  onTap: () => _vote(idx, currentPollData),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: double.infinity,
                    height: 52,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white.withOpacity(0.03) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF306CFE)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        if (hasVoted)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: percentageFactor,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF306CFE).withOpacity(isSelected ? 0.25 : 0.15),
                                      const Color(0xFF306CFE).withOpacity(isSelected ? 0.35 : 0.20),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 45),
                            child: Text(
                              text,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected 
                                  ? const Color(0xFF306CFE) 
                                  : (isDarkMode ? Colors.white : const Color(0xFF4A5568)),
                              ),
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Positioned(
                            left: 12,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Icon(Icons.check_circle, size: 20, color: Color(0xFF306CFE)),
                            ),
                          ),
                        if (hasVoted)
                          Positioned(
                            right: 12,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Text(
                                "$percentageValue%",
                                style: TextStyle(
                                  fontFamily: 'Encode Sans Expanded',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? const Color(0xFF306CFE) : (isDarkMode ? Colors.white38 : Colors.grey[600]),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              if (hasVoted)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF306CFE).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Color(0xFF306CFE)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "Bạn có thể chọn nhiều đáp án hoặc nhấn để hủy",
                              style: TextStyle(
                                fontFamily: 'Encode Sans Expanded',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF306CFE),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
