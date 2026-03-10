import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'features/navigation/data/datasources/hybrid_beacon_datasource.dart';
import 'features/navigation/data/datasources/map_datasource.dart';
import 'features/navigation/data/repositories/beacon_repository_impl.dart';
import 'features/navigation/data/repositories/navigation_repository_impl.dart';
import 'features/configuration/configuration.dart';
import 'features/configuration/data/services/firebase_configuration_service.dart';
import 'features/navigation/presentation/logic/beacon_cubit.dart';
import 'features/navigation/presentation/logic/navigation_cubit.dart';
import 'features/navigation/presentation/views/indoor_map_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
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
        // Configuration Repository (must come first)
        RepositoryProvider<ConfigurationRepository>(
          create: (_) => ConfigurationRepository(
            LocalConfigurationStorageService(),
            firebaseService: FirebaseConfigurationService(),
          ),
        ),
        
        // Data sources
        RepositoryProvider<HybridBeaconDataSource>(
          create: (context) => HybridBeaconDataSource(
            context.read<ConfigurationRepository>(),
          ),
        ),
        RepositoryProvider<StaticMapDataSource>(
          create: (_) => StaticMapDataSource(),
        ),
        
        // Repositories
        RepositoryProvider<BeaconRepositoryImpl>(
          create: (context) => BeaconRepositoryImpl(
            context.read<HybridBeaconDataSource>(),
            context.read<ConfigurationRepository>(),
          ),
        ),
        RepositoryProvider<NavigationRepositoryImpl>(
          create: (context) => NavigationRepositoryImpl(
            mapDataSource: context.read<StaticMapDataSource>(),
            beaconDataSource: context.read<HybridBeaconDataSource>(),
            configurationRepository: context.read<ConfigurationRepository>(),
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
          BlocProvider<ConfigurationCubit>(
            create: (context) => ConfigurationCubit(
              context.read<ConfigurationRepository>(),
            )..loadConfiguration(),
          ),
        ],
        child: MaterialApp(
          title: 'Hospital Indoor Navigation',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const IndoorMapView(
            showConfigurationButton: true,
          ),
        ),
      ),
    );
  }
}
