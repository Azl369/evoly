import 'package:flutter/material.dart';
import 'package:evoly/app/main_shell_page.dart';
import 'package:evoly/features/documents/presentation/document_edit_page.dart';
import 'package:evoly/features/documents/presentation/goal_document_folder_page.dart';
import 'package:evoly/features/goals/presentation/goal_detail_page.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';

class AppRoutes {
  static const today = '/';
  static const goals = '/goals';
  static const goalDetail = '/goals/detail';
  static const documents = '/documents';
  static const documentEdit = '/documents/edit';
  static const documentGoalFolder = '/documents/goal-folder';
  static const stats = '/stats';
  static const settings = '/settings';

  static const topLevelRoutes = {
    today,
    goals,
    documents,
    stats,
    settings,
  };

  static bool isTopLevel(String? routeName) {
    return topLevelRoutes.contains(routeName);
  }
}

class GoalDetailRouteArguments {
  const GoalDetailRouteArguments({
    required this.goalId,
    this.initialTaskId,
  });

  final String goalId;
  final String? initialTaskId;
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final page = switch (settings.name) {
      AppRoutes.today => const MainShellPage(initialIndex: 0),
      AppRoutes.goals => const MainShellPage(initialIndex: 1),
      AppRoutes.goalDetail => _goalDetailPage(settings.arguments),
      AppRoutes.documents => const MainShellPage(initialIndex: 2),
      AppRoutes.documentEdit => _documentEditPage(settings.arguments),
      AppRoutes.documentGoalFolder => GoalDocumentFolderPage(
          goalId:
              settings.arguments is String ? settings.arguments! as String : '',
        ),
      AppRoutes.stats => const MainShellPage(initialIndex: 3),
      AppRoutes.settings => const MainShellPage(initialIndex: 4),
      _ => const MainShellPage(initialIndex: 0),
    };
    final isTopLevelRoute = AppRoutes.isTopLevel(settings.name);

    return PageRouteBuilder(
      settings: settings,
      transitionDuration:
          isTopLevelRoute ? MotionTokens.instant : MotionTokens.normal,
      reverseTransitionDuration: MotionTokens.fast,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        if (isTopLevelRoute) {
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: MotionTokens.gentle,
          );

          return FadeTransition(
            opacity: Tween<double>(
              begin: 0.96,
              end: 1,
            ).animate(fadeAnimation),
            child: child,
          );
        }

        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: MotionTokens.standard,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0.02),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  static GoalDetailPage _goalDetailPage(Object? arguments) {
    if (arguments is GoalDetailRouteArguments) {
      return GoalDetailPage(
        goalId: arguments.goalId,
        initialTaskId: arguments.initialTaskId,
      );
    }

    return GoalDetailPage(
      goalId: arguments is String ? arguments : '',
    );
  }

  static DocumentEditPage _documentEditPage(Object? arguments) {
    if (arguments is DocumentEditArguments) {
      return DocumentEditPage(
        documentId: arguments.documentId,
        initialLinkedGoalId: arguments.initialLinkedGoalId,
        initialTitle: arguments.initialTitle,
        initialContentMarkdown: arguments.initialContentMarkdown,
        initialType: arguments.initialType,
      );
    }

    return DocumentEditPage(
      documentId: arguments is String ? arguments : null,
    );
  }
}
