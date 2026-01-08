import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'data/datasources/hybrid_beacon_datasource.dart';
import 'data/datasources/map_datasource.dart';
import 'data/repositories/beacon_repository_impl.dart';
import 'data/repositories/navigation_repository_impl.dart';
import 'presentation/logic/beacon_cubit.dart';
import 'presentation/logic/navigation_cubit.dart';
import 'presentation/views/indoor_map_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const HospitalNavigationApp());
}

class HospitalNavigationApp extends StatelessWidget {
  const HospitalNavigationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<HybridBeaconDataSource>(
          create: (_) => HybridBeaconDataSource(),
        ),
        RepositoryProvider<StaticMapDataSource>(
          create: (_) => StaticMapDataSource(),
        ),
        RepositoryProvider<BeaconRepositoryImpl>(
          create: (context) => BeaconRepositoryImpl(
            context.read<HybridBeaconDataSource>(),
          ),
        ),
        RepositoryProvider<NavigationRepositoryImpl>(
          create: (context) => NavigationRepositoryImpl(
            mapDataSource: context.read<StaticMapDataSource>(),
            beaconDataSource: context.read<HybridBeaconDataSource>(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<BeaconCubit>(
            create: (context) => BeaconCubit(
              context.read<BeaconRepositoryImpl>(),
            ),
          ),
          BlocProvider<NavigationCubit>(
            create: (context) => NavigationCubit(
              navigationRepository: context.read<NavigationRepositoryImpl>(),
              beaconRepository: context.read<BeaconRepositoryImpl>(),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Hospital Indoor Navigation',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const IndoorMapView(),
        ),
      ),
    );
  }
}
