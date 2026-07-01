import 'package:flutter/material.dart';
import 'package:evoly/shared/widgets/empty_state.dart';

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyState(
        icon: Icons.rate_review_outlined,
        title: '还没有复盘',
        message: '完成一个目标后，这里会帮助你记录经验。',
      ),
    );
  }
}
