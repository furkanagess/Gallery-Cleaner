import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ViewRefreshCubit extends Cubit<int> {
  ViewRefreshCubit() : super(0);

  void refresh() => emit(state + 1);
}

mixin CubitStateMixin<T extends StatefulWidget> on State<T> {
  late final ViewRefreshCubit _viewRefreshCubit = ViewRefreshCubit();

  @protected
  ViewRefreshCubit get viewRefreshCubit => _viewRefreshCubit;

  @protected
  void cubitSetState(VoidCallback fn) {
    fn();
    _viewRefreshCubit.refresh();
  }

  @protected
  Widget buildWithCubit(Widget Function() builder) {
    return BlocBuilder<ViewRefreshCubit, int>(
      bloc: _viewRefreshCubit,
      buildWhen: (previous, current) => previous != current,
      builder: (_, _) => builder(),
    );
  }

  @override
  void dispose() {
    _viewRefreshCubit.close();
    super.dispose();
  }
}
