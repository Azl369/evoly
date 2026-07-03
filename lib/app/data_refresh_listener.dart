import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/data_refresh_controller.dart';

mixin DataRefreshListener<T extends StatefulWidget> on State<T> {
  DataRefreshController? _dataRefreshController;
  var _lastSeenDataRevision = 0;

  Future<void> reloadDataForRefresh();

  void notifyDataChanged() {
    try {
      context.read<DataRefreshController>().markChanged();
    } on ProviderNotFoundException {
      return;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final DataRefreshController controller;
    try {
      controller = context.read<DataRefreshController>();
    } on ProviderNotFoundException {
      return;
    }

    if (controller == _dataRefreshController) {
      return;
    }

    _dataRefreshController?.removeListener(_handleDataRefresh);
    _dataRefreshController = controller;
    _lastSeenDataRevision = controller.revision;
    controller.addListener(_handleDataRefresh);
  }

  void _handleDataRefresh() {
    final controller = _dataRefreshController;
    if (!mounted || controller == null) {
      return;
    }

    if (controller.revision == _lastSeenDataRevision) {
      return;
    }

    _lastSeenDataRevision = controller.revision;
    unawaited(reloadDataForRefresh());
  }

  @override
  void dispose() {
    _dataRefreshController?.removeListener(_handleDataRefresh);
    super.dispose();
  }
}
