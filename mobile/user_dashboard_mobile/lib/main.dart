import 'package:flutter/material.dart';import 'package:flutter/material.dart';import 'package:flutter/material.dart';import 'package:flutter/material.dart';import 'package:flutter/material.dart';import 'package:flutter/material.dart';



void main() {import 'package:provider/provider.dart';

  runApp(const MyApp());

}import 'package:go_router/go_router.dart';import 'package:provider/provider.dart';



class MyApp extends StatelessWidget {

  const MyApp({super.key});

import 'providers/auth_provider.dart';import 'package:go_router/go_router.dart';import 'package:provider/provider.dart';

  @override

  Widget build(BuildContext context) {import 'providers/dashboard_provider.dart';

    return MaterialApp(

      title: 'User Dashboard Mobile',import 'screens/auth_screen.dart';

      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),import 'screens/dashboard_screen.dart';

        useMaterial3: true,

      ),import 'screens/profile_screen.dart';import 'providers/auth_provider.dart';import 'package:flutter_secure_storage/flutter_secure_storage.dart';import 'package:provider/provider.dart';import 'package:provider/provider.dart';

      home: const MyHomePage(),

    );

  }

}void main() {import 'providers/dashboard_provider.dart';



class MyHomePage extends StatelessWidget {  runApp(const UserDashboardApp());

  const MyHomePage({super.key});

}import 'screens/auth_screen.dart';

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(class UserDashboardApp extends StatelessWidget {import 'screens/dashboard_screen.dart';

        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: const Text('Flutter Mobile Dashboard'),  const UserDashboardApp({super.key});

      ),

      body: const Center(import 'screens/profile_screen.dart';import 'providers/auth_provider.dart';import 'package:go_router/go_router.dart';import 'package:go_router/go_router.dart';

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,  @override

          children: <Widget>[

            Text(  Widget build(BuildContext context) {

              'Welcome to the User Dashboard Mobile App!',

              style: TextStyle(fontSize: 18),    return MultiProvider(

              textAlign: TextAlign.center,

            ),      providers: [void main() {import 'providers/dashboard_provider.dart';

            SizedBox(height: 20),

            Text(        ChangeNotifierProvider(create: (_) => AuthProvider()),

              'This is a Flutter mobile version of the user dashboard.',

              style: TextStyle(fontSize: 16, color: Colors.grey),        ChangeNotifierProvider(create: (_) => DashboardProvider()),  runApp(const MyApp());

              textAlign: TextAlign.center,

            ),      ],

          ],

        ),      child: Consumer<AuthProvider>(}import 'services/api_service.dart';import 'package:flutter_secure_storage/flutter_secure_storage.dart';import 'package:flutter_secure_storage/flutter_secure_storage.dart';

      ),

    );        builder: (context, authProvider, child) {

  }

}          return MaterialApp.router(

            title: 'User Dashboard',

            theme: ThemeData(class MyApp extends StatelessWidget {import 'screens/auth_screen.dart';

              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),

              useMaterial3: true,  const MyApp({super.key});

            ),

            routerConfig: _createRouter(authProvider),import 'screens/dashboard_screen.dart';

          );

        },  @override

      ),

    );  Widget build(BuildContext context) {import 'screens/profile_screen.dart';

  }

    return MultiProvider(

  GoRouter Function(AuthProvider auth) _createRouter {

    return GoRouter(      providers: [import 'providers/auth_provider.dart';import 'providers/auth_provider.dart';

      initialLocation: auth.isAuthenticated ? '/dashboard' : '/auth',

      redirect: (context, state) {        ChangeNotifierProvider(create: (_) => AuthProvider()),

        final isAuthenticated = auth.isAuthenticated;

        final isOnAuth = state.fullPath == '/auth';        ChangeNotifierProvider(create: (_) => DashboardProvider()),void main() {



        if (!isAuthenticated && !isOnAuth) {      ],

          return '/auth';

        }      child: Consumer<AuthProvider>(  runApp(UserDashboardApp());import 'providers/dashboard_provider.dart';import 'providers/dashboard_provider.dart';



        if (isAuthenticated && isOnAuth) {        builder: (context, authProvider, child) {

          return '/dashboard';

        }          final router = GoRouter(}



        return null;            initialLocation: authProvider.isAuthenticated ? '/dashboard' : '/auth',

      },

      routes: [            redirect: (context, state) {import 'services/api_service.dart';import 'services/api_service.dart';

        GoRoute(

          path: '/auth',              final isAuthenticated = authProvider.isAuthenticated;

          builder: (context, state) => const AuthScreen(),

        ),              final isOnAuth = state.fullPath == '/auth';class UserDashboardApp extends StatelessWidget {

        GoRoute(

          path: '/dashboard',              

          builder: (context, state) => const DashboardScreen(),

        ),              if (!isAuthenticated && !isOnAuth) {  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();import 'screens/auth_screen.dart';import 'screens/auth_screen.dart';

        GoRoute(

          path: '/profile',                return '/auth';

          builder: (context, state) => const ProfileScreen(),

        ),              }  final ApiService _apiService = ApiService();

      ],

    );              

  }

}              if (isAuthenticated && isOnAuth) {import 'screens/dashboard_screen.dart';import 'screens/dashboard_screen.dart';

                return '/dashboard';

              }  UserDashboardApp({Key? key}) : super(key: key);

              

              return null;import 'screens/profile_screen.dart';import 'screens/profile_screen.dart';

            },

            routes: [  @override

              GoRoute(

                path: '/auth',  Widget build(BuildContext context) {

                builder: (context, state) => const AuthScreen(),

              ),    return MultiProvider(

              GoRoute(

                path: '/dashboard',      providers: [void main() {void main() {

                builder: (context, state) => const MainScreen(),

              ),        ChangeNotifierProvider(

              GoRoute(

                path: '/profile',          create: (context) => AuthProvider(_secureStorage, _apiService),  runApp(UserDashboardApp());  runApp(UserDashboardApp());

                builder: (context, state) => const ProfileScreen(),

              ),        ),

            ],

          );        ChangeNotifierProvider(}}



          return MaterialApp.router(          create: (context) => DashboardProvider(_apiService),

            title: 'User Dashboard',

            theme: ThemeData(        ),

              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),

              useMaterial3: true,      ],

              inputDecorationTheme: InputDecorationTheme(

                border: OutlineInputBorder(      child: MaterialApp(class UserDashboardApp extends StatelessWidget {class UserDashboardApp extends StatelessWidget {

                  borderRadius: BorderRadius.circular(8),

                ),        title: 'User Dashboard Mobile',

                fillColor: Colors.grey.shade50,

                filled: true,        theme: ThemeData(  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

              ),

            ),          primarySwatch: Colors.blue,

            routerConfig: router,

          );          useMaterial3: true,  final ApiService _apiService = ApiService();  final ApiService _apiService = ApiService();

        },

      ),        ),

    );

  }        home: Consumer<AuthProvider>(

}

          builder: (context, auth, child) {

class MainScreen extends StatefulWidget {

  const MainScreen({super.key});            if (auth.isLoading) {  UserDashboardApp({Key? key}) : super(key: key);  UserDashboardApp({Key? key}) : super(key: key);



  @override              return const Scaffold(

  State<MainScreen> createState() => _MainScreenState();

}                body: Center(



class _MainScreenState extends State<MainScreen> {                  child: CircularProgressIndicator(),

  int _selectedIndex = 0;

                ),  @override  @override

  final List<Widget> _screens = [

    const DashboardScreen(),              );

    LeaderboardScreen(),

    ProfileScreen(),            }  Widget build(BuildContext context) {  Widget build(BuildContext context) {

  ]



  @override

  Widget build(BuildContext context) {            if (!auth.isAuthenticated) {    return MultiProvider(    return MultiProvider(

    return Consumer<AuthProvider>(

      builder: (context, authProvider, child) {              return const AuthScreen();

        if (authProvider.isLoading) {

          return Scaffold(            }      providers: [      providers: [

            body: Container(

              decoration: BoxDecoration(

                gradient: LinearGradient(

                  begin: Alignment.topCenter,            return const MainScreen();        ChangeNotifierProvider(        ChangeNotifierProvider(

                  end: Alignment.bottomCenter,

                  colors: [          },

                    Colors.blue.shade100,

                    Colors.white,        ),          create: (context) => AuthProvider(_secureStorage, _apiService),          create: (context) => AuthProvider(_secureStorage, _apiService),

                  ],

                ),      ),

              ),

              child: const Center(    );        ),        ),

                child: Column(

                  mainAxisAlignment: MainAxisAlignment.center,  }

                  children: [

                    CircularProgressIndicator(),}        ChangeNotifierProvider(        ChangeNotifierProvider(

                    SizedBox(height: 16),

                    Text(

                      'Loading...',

                      style: TextStyle(class MainScreen extends StatefulWidget {          create: (context) => DashboardProvider(_apiService),          create: (context) => DashboardProvider(_apiService),

                        fontSize: 16,

                        color: Colors.grey,  const MainScreen({Key? key}) : super(key: key);

                      ),

                    ),        ),        ),

                  ],

                ),  @override

              ),

            ),  State<MainScreen> createState() => _MainScreenState();      ],      ],

          )

        }}



        return Scaffold(      child = Consumer<AuthProvider>(      child: Consumer<AuthProvider>(

          body: IndexedStack(

            index: _selectedIndex,class _MainScreenState extends State<MainScreen> {

            children: _screens,

          ),  int _selectedIndex = 0;        builder: (context, auth, child) {        builder: (context, auth, child) {

          bottomNavigationBar: BottomNavigationBar(

            currentIndex: _selectedIndex,

            onTap: (index) {

              setState(() {  final List<Widget> _screens = [          return MaterialApp.router(          return MaterialApp.router(

                _selectedIndex = index;

              });    const DashboardScreen(),

            },

            items: const [    const Center(child: Text('Leaderboard')),            title: 'User Dashboard Mobile',            title: 'User Dashboard Mobile',

              BottomNavigationBarItem(

                icon: Icon(Icons.dashboard),    const ProfileScreen(),

                label: 'Dashboard',

              ),  ];            theme: ThemeData(            theme: ThemeData(

              BottomNavigationBarItem(

                icon: Icon(Icons.leaderboard),

                label: 'Leaderboard',

              ),  @override              primarySwatch: Colors.blue,              primarySwatch: Colors.blue,

              BottomNavigationBarItem(

                icon: Icon(Icons.person),  Widget build(BuildContext context) {

                label: 'Profile',

              ),    return Scaffold(              useMaterial3: true,              useMaterial3: true,

            ],

          ),      body: _screens[_selectedIndex],

        );

      },      bottomNavigationBar: BottomNavigationBar(              appBarTheme: AppBarTheme(              appBarTheme: AppBarTheme(

    );

  }        currentIndex: _selectedIndex,

}

        onTap: (index) {                backgroundColor: Colors.blue.shade600,                backgroundColor: Colors.blue.shade600,

class LeaderboardScreen extends StatefulWidget {

  const LeaderboardScreen({super.key});          setState(() {



  @override            _selectedIndex = index;                foregroundColor: Colors.white,                foregroundColor: Colors.white,

  State<LeaderboardScreen> createState() => _LeaderboardScreenState();

}          });



class _LeaderboardScreenState extends State<LeaderboardScreen> {        },                elevation: 2,                elevation: 2,

  @override

  void initState() {        items: const [

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {          BottomNavigationBarItem(              ),              ),

      context.read<DashboardProvider>().loadLeaderboard();

    });            icon: Icon(Icons.dashboard),

  }

            label: 'Dashboard',              cardTheme: CardTheme(              cardTheme: CardTheme(

  void _refreshLeaderboard() {

    context.read<DashboardProvider>().loadLeaderboard();          ),

  }

          BottomNavigationBarItem(                elevation: 2,                elevation: 2,

  @override

  Widget build(BuildContext context) {            icon: Icon(Icons.leaderboard),

    return Scaffold(

      appBar: AppBar(            label: 'Leaderboard',                shape: RoundedRectangleBorder(                shape: RoundedRectangleBorder(

        title: const Text('Leaderboard'),

        backgroundColor: Colors.amber.shade600,          ),

        foregroundColor: Colors.white,

        elevation: 2,          BottomNavigationBarItem(                  borderRadius: BorderRadius.circular(12),                  borderRadius: BorderRadius.circular(12),

        actions: [

          IconButton(            icon: Icon(Icons.person),

            icon: const Icon(Icons.refresh),

            onPressed: _refreshLeaderboard,            label: 'Profile',                ),                ),

          ),

        ],          ),

      ),

      body: RefreshIndicator(        ],              ),              ),

        onRefresh: () async => _refreshLeaderboard(),

        child: Consumer<DashboardProvider>(      ),

          builder: (context, dashboardProvider, child) {

            if (dashboardProvider.isLoading) {    );              elevatedButtonTheme: ElevatedButtonThemeData(              elevatedButtonTheme: ElevatedButtonThemeData(

              return const Center(child: CircularProgressIndicator());

            }  }



            final leaderboard = dashboardProvider.leaderboard;}                style: ElevatedButton.styleFrom(                style: ElevatedButton.styleFrom(



            if (leaderboard.isEmpty) {                  elevation: 2,                  elevation: 2,

              return const Center(

                child: Column(                  shape: RoundedRectangleBorder(                  shape: RoundedRectangleBorder(

                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [                    borderRadius: BorderRadius.circular(8),                    borderRadius: BorderRadius.circular(8),

                    Icon(Icons.emoji_events, size: 64, color: Colors.grey),

                    SizedBox(height: 16),                  ),                  ),

                    Text(

                      'No leaderboard data available',                ),                ),

                      style: TextStyle(fontSize: 18, color: Colors.grey),

                    ),              ),              ),

                  ],

                ),              inputDecorationTheme: InputDecorationTheme(              inputDecorationTheme: InputDecorationTheme(

              );

            }                border: OutlineInputBorder(                border: OutlineInputBorder(



            return ListView.builder(                  borderRadius: BorderRadius.circular(8),                  borderRadius: BorderRadius.circular(8),

              padding: const EdgeInsets.all(16),

              itemCount: leaderboard.length,                ),                ),

              itemBuilder: (context, index) {

                final entry = leaderboard[index];                filled: true,                filled: true,

                

                Color? rankColor;                fillColor: Colors.grey.shade50,                fillColor: Colors.grey.shade50,

                IconData? rankIcon;

                              ),              ),

                if (entry.rank == 1) {

                  rankColor = Colors.amber.shade600;            ),            routerConfig: _createRouter(auth),

                  rankIcon = Icons.emoji_events;

                } else if (entry.rank == 2) {            routerConfig: _createRouter(auth),          )

                  rankColor = Colors.grey.shade500;

                  rankIcon = Icons.emoji_events;          )        },

                } else if (entry.rank == 3) {

                  rankColor = Colors.brown.shade400;        },      ),

                  rankIcon = Icons.emoji_events;

                }      ),    );



                return Card(    );  }

                  margin: EdgeInsets.only(bottom = 12),

                  child: Container(  }

                    decoration: BoxDecoration(

                      borderRadius: BorderRadius.circular(12),  GoRouter _createRouter(AuthProvider auth) {

                      color: entry.rank <= 3 ? rankColor?.withOpacity(0.1) : null,

                    ),  GoRouter _createRouter(AuthProvider auth) {    return GoRouter(

                    child: Padding(

                      padding: const EdgeInsets.all(16),    return GoRouter(      initialLocation: '/dashboard',

                      child: Row(

                        children: [      initialLocation: '/auth',      redirect: (context, state) {

                          Container(

                            width: 40,      redirect: (context, state) {        final isAuthenticated = auth.isAuthenticated;

                            height: 40,

                            decoration: BoxDecoration(        final isAuthenticated = auth.isAuthenticated;        final isOnAuth = state.fullPath == '/auth';

                              color: rankColor,

                              borderRadius: BorderRadius.circular(20),        final isOnAuth = state.fullPath == '/auth';        final isLoading = auth.isLoading;

                            ),

                            child: Center(        final isLoading = auth.isLoading;

                              child: rankIcon != null

                                  ? Icon(        // Show loading while checking auth

                                      rankIcon,

                                      color: Colors.white,        // Show loading while checking auth        if (isLoading) {

                                      size: 20,

                                    )        if (isLoading) {          return null;

                                  : Text(

                                      '#${entry.rank}',          return null;        }

                                      style: const TextStyle(

                                        color: Colors.white,        }

                                        fontWeight: FontWeight.bold,

                                      ),        // If not authenticated and not on auth page, go to auth

                                    ),

                            ),        // If not authenticated and not on auth page, go to auth        if (!isAuthenticated && !isOnAuth) {

                          ),

                          const SizedBox(width: 16),        if (!isAuthenticated && !isOnAuth) {          return '/auth';

                          CircleAvatar(

                            radius: 24,          return '/auth';        }

                            backgroundColor: Colors.blue.shade100,

                            backgroundImage: entry.profileImageUrl != null         }

                                ? NetworkImage(entry.profileImageUrl!)

                                : null,        // If authenticated and on auth page, go to dashboard

                            child: entry.profileImageUrl == null

                                ? Text(        // If authenticated and on auth page, go to dashboard        if (isAuthenticated && isOnAuth) {

                                    entry.displayName.substring(0, 1).toUpperCase(),

                                    style: TextStyle(        if (isAuthenticated && isOnAuth) {          return '/dashboard';

                                      color: Colors.blue.shade600,

                                      fontWeight: FontWeight.bold,          return '/dashboard';        }

                                    ),

                                  )        }

                                : null,

                          ),        return null;

                          SizedBox(width = 16),

                          Expanded(        return null;      },

                            child: Column(

                              crossAxisAlignment: CrossAxisAlignment.start,      },      routes: [

                              children: [

                                Text(      routes: [        GoRoute(

                                  entry.displayName,

                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(        GoRoute(          path: '/auth',

                                    fontWeight: FontWeight.bold,

                                  ),          path: '/auth',          builder: (context, state) => const AuthScreen(),

                                ),

                                if (entry.displayName != entry.username) ...[          builder: (context, state) => const AuthScreen(),        ),

                                  Text(

                                    '@${entry.username}',        ),        GoRoute(

                                    style: TextStyle(

                                      color: Colors.grey.shade600,        GoRoute(          path: '/dashboard',

                                      fontSize: 12,

                                    ),          path: '/dashboard',          builder: (context, state) => const MainScreen(),

                                  ),

                                ],          builder: (context, state) => const MainScreen(),        ),

                              ],

                            ),        ),        GoRoute(

                          ),

                          Container(        GoRoute(          path = '/profile',

                            padding = const EdgeInsets.symmetric(

                              horizontal: 12,          path: '/profile',          builder: (context, state) => const ProfileScreen(),

                              vertical: 6,

                            ),          builder = (context, state) => const ProfileScreen(),        ),

                            decoration = BoxDecoration(

                              color: Colors.blue.shade50,        ),      ],

                              borderRadius: BorderRadius.circular(16),

                              border: Border.all(color: Colors.blue.shade200),      ],    );

                            ),

                            child: Column(    );  }

                              children: [

                                Text(  }}

                                  '${entry.totalScore.toStringAsFixed(0)}',

                                  style: TextStyle(}

                                    color: Colors.blue.shade600,

                                    fontWeight: FontWeight.bold,class MainScreen extends StatefulWidget {

                                    fontSize: 16,

                                  ),class MainScreen extends StatefulWidget {  const MainScreen({Key? key}) : super(key: key);

                                ),

                                Text(  Function({Key? key}) MainScreen = super(key: key);

                                  'points',

                                  style: TextStyle(  @override

                                    color: Colors.blue.shade600,

                                    fontSize: 10,  @override  State<MainScreen> createState() => _MainScreenState();

                                  ),

                                ),  State<MainScreen> createState() => _MainScreenState();}

                              ],

                            ),}

                          ),

                        ],class _MainScreenState extends State<MainScreen> {

                      ),

                    ),class _MainScreenState extends State<MainScreen> {  int selectedIndex = 0;

                  ),

                )  int selectedIndex = 0;

              },

            );  final List<Widget> _screens = [

          },

        ),  final List<Widget> _screens = [    const DashboardScreen(),

      ),

    );    const DashboardScreen(),    const LeaderboardScreen(),

  }

}    const LeaderboardScreen(),    const ProfileScreen(),

    const ProfileScreen(),  ];

  ];

  @override

  @override  Widget build(BuildContext context) {

  Widget build(BuildContext context) {    return Consumer<AuthProvider>(

    return Consumer<AuthProvider>(      builder: (context, authProvider, child) {

      builder: (context, authProvider, child) {        if (authProvider.isLoading) {

        if (authProvider.isLoading) {          return Scaffold(

          return Scaffold(            body: Container(

            body: Container(              decoration: BoxDecoration(

              decoration: BoxDecoration(                gradient: LinearGradient(

                gradient: LinearGradient(                  begin: Alignment.topCenter,

                  begin: Alignment.topCenter,                  end: Alignment.bottomCenter,

                  end: Alignment.bottomCenter,                  colors: [

                  colors: [                    Colors.blue.shade100,

                    Colors.blue.shade100,                    Colors.indigo.shade50,

                    Colors.indigo.shade50,                  ],

                  ],                ),

                ),              ),

              ),              child: const Center(

              child: Center(                child: Column(

                child: Column(                  mainAxisAlignment: MainAxisAlignment.center,

                  mainAxisAlignment: MainAxisAlignment.center,                  children: [

                  children: [                    CircularProgressIndicator(),

                    CircularProgressIndicator(),                    SizedBox(height: 16),

                    SizedBox(height: 16),                    Text('Loading...'),

                    Text('Loading...'),                  ],

                  ],                ),

                ),              ),

              ),            ),

            ),          );

          );        }

        }

        if (!authProvider.isAuthenticated) {

        if (!authProvider.isAuthenticated) {          return const AuthScreen();

          return const AuthScreen();        }

        }

        return Scaffold(

        return Scaffold(          body: IndexedStack(

          body: IndexedStack(            index: _selectedIndex,

            index: _selectedIndex,            children: _screens,

            children: _screens,          ),

          ),          bottomNavigationBar: BottomNavigationBar(

          bottomNavigationBar: BottomNavigationBar(            currentIndex: _selectedIndex,

            currentIndex: _selectedIndex,            onTap: (index) {

            onTap: (index) {              setState(() {

              setState(() {                _selectedIndex = index;

                _selectedIndex = index;              });

              });            },

            },            type: BottomNavigationBarType.fixed,

            type: BottomNavigationBarType.fixed,            selectedItemColor: Colors.blue.shade600,

            selectedItemColor: Colors.blue.shade600,            unselectedItemColor: Colors.grey.shade600,

            unselectedItemColor: Colors.grey.shade600,            items: const [

            items: const [              BottomNavigationBarItem(

              BottomNavigationBarItem(                icon: Icon(Icons.dashboard),

                icon: Icon(Icons.dashboard),                label: 'Dashboard',

                label: 'Dashboard',              ),

              ),              BottomNavigationBarItem(

              BottomNavigationBarItem(                icon: Icon(Icons.leaderboard),

                icon: Icon(Icons.leaderboard),                label: 'Leaderboard',

                label: 'Leaderboard',              ),

              ),              BottomNavigationBarItem(

              BottomNavigationBarItem(                icon: Icon(Icons.person),

                icon: Icon(Icons.person),                label: 'Profile',

                label: 'Profile',              ),

              ),            ],

            ],          ),

          ),        );

        );      },

      },    );

    );  }

  }}

}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});


class LeaderboardScreen extends StatefulWidget {  const LeaderboardScreen({Key? key}) : super(key: key);

  const LeaderboardScreen({Key? key}) : super(key: key);

  @override

  @override  State<LeaderboardScreen> createState() => _LeaderboardScreenState();

  State<LeaderboardScreen> createState() => _LeaderboardScreenState();}

}

class _LeaderboardScreenState extends State<LeaderboardScreen> {

class _LeaderboardScreenState extends State<LeaderboardScreen> {      body: Center(

  @override        // Center is a layout widget. It takes a single child and positions it

  void initState() {        // in the middle of the parent.

    super.initState();        child: Column(

    _loadLeaderboard();          // Column is also a layout widget. It takes a list of children and

  }          // arranges them vertically. By default, it sizes itself to fit its

          // children horizontally, and tries to be as tall as its parent.

  void _loadLeaderboard() {          //

    final authProvider = Provider.of<AuthProvider>(context, listen: false);          // Column has various properties to control how it sizes itself and

    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);          // how it positions its children. Here we use mainAxisAlignment to

          // center the children vertically; the main axis here is the vertical

    if (authProvider.currentOrganization != null) {          // axis because Columns are vertical (the cross axis would be

      dashboardProvider.refreshLeaderboard(authProvider.currentOrganization!);          // horizontal).

    }          //

  }          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"

          // action in the IDE, or press "p" in the console), to see the

  Future<void> _refreshLeaderboard() async {          // wireframe for each widget.

    _loadLeaderboard();          mainAxisAlignment: MainAxisAlignment.center,

  }          children: <Widget>[

            const Text('You have pushed the button this many times:'),

  @override            Text(

  Widget build(BuildContext context) {              '$_counter',

    return Scaffold(              style: Theme.of(context).textTheme.headlineMedium,

      appBar: AppBar(            ),

        title: const Text('Leaderboard'),          ],

        backgroundColor: Colors.amber.shade600,        ),

        foregroundColor: Colors.white,      ),

        elevation: 2,      floatingActionButton: FloatingActionButton(

      ),        onPressed: _incrementCounter,

      body: RefreshIndicator(        tooltip: 'Increment',

        onRefresh: _refreshLeaderboard,

        child: Consumer<DashboardProvider>(      ), // This trailing comma makes auto-formatting nicer for build methods.

          builder: (context, dashboardProvider, child) {    ,        child: const Icon(Icons.add));

            if (dashboardProvider.isLoading) {  }

              return const Center(}

                child: CircularProgressIndicator(),
              );
            }

            final leaderboard = dashboardProvider.leaderboard;

            if (leaderboard.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.leaderboard,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No leaderboard data available',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for rankings',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshLeaderboard,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding = const EdgeInsets.all(16),
              itemCount = leaderboard.length,
              itemBuilder = (context, index) {
                final entry = leaderboard[index];
                
                Color rankColor = Colors.grey.shade600;
                IconData? rankIcon;

                if (entry.rank == 1) {
                  rankColor = Colors.amber.shade600;
                  rankIcon = Icons.emoji_events;
                } else if (entry.rank == 2) {
                  rankColor = Colors.grey.shade500;
                  rankIcon = Icons.emoji_events;
                } else if (entry.rank == 3) {
                  rankColor = Colors.brown.shade400;
                  rankIcon = Icons.emoji_events;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: entry.rank <= 3 ? rankColor.withOpacity(0.1) : null,
                    ),
                    child: Row(
                      children: [
                        // Rank
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: rankColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: rankIcon != null
                                ? Icon(
                                    rankIcon,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : Text(
                                    '#${entry.rank}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),

                        // Avatar
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: entry.profileImageUrl != null 
                              ? NetworkImage(entry.profileImageUrl!)
                              : null,
                          child: entry.profileImageUrl == null
                              ? Text(
                                  entry.displayName.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),

                        const SizedBox(width: 16),

                        // Name and details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (entry.displayName != entry.username) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '@${entry.username}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Score
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${entry.totalScore.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                'points',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}