import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:q_flutter_test/app_widgets/posts_error.dart';
import 'package:q_flutter_test/app_widgets/posts_loaded.dart';
import 'package:q_flutter_test/models/local_storage.dart';
import 'package:q_flutter_test/models/posts_data.dart';
import 'package:q_flutter_test/models/posts_state.dart';
import 'package:q_flutter_test/models/state_provider.dart';

class PostsView extends ConsumerStatefulWidget {
  const PostsView({Key? key}) : super(key: key);

  @override
  ConsumerState<PostsView> createState() => _PostsViewState();
}

class _PostsViewState extends ConsumerState<PostsView>
    with WidgetsBindingObserver {
  Posts post = Posts();
  late RefreshController _refreshController;
  int _postID = 4;
  List<Posts> posts = [];
  StreamSubscription<ConnectivityResult>? subscription;
  bool hideInitialConnection = true;
  bool wentOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    _refreshController = RefreshController(initialRefresh: true);
    subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (!hideInitialConnection) {
        if (result != ConnectivityResult.none) {
          online();
        } else {
          offline();
        }
      }
      hideInitialConnection = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      // await Hive.close();
    } else if (state == AppLifecycleState.resumed) {
      hideInitialConnection = true;
      // await Hive.openBox<Posts>('posts');
    } else if (state == AppLifecycleState.paused) {
      // await Hive.close();
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _postID = 4;
    Hive.close();
    subscription!.cancel();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 79, 255, 0),
          title: const Center(
              child: Text(
            'Q Test',
            style: TextStyle(color: Colors.black),
          )),
          elevation: 0,
        ),
        body: SafeArea(
          child: SizedBox(
            width: screenWidth,
            child: SmartRefresher(
              enablePullUp:
                  (ref.watch(postsNotifierProvider) is! PostsLocalStorage),
              enablePullDown:
                  (ref.watch(postsNotifierProvider) is! PostsLocalStorage),
              controller: _refreshController,
              onLoading: () => _onLoading(posts: posts),
              onRefresh: _onRefresh,
              child: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(postsNotifierProvider);
                  if (state is PostsNoInternetState) {
                    return PostsError(
                      error: state.error,
                      isConnected: false,
                      ref: ref,
                    );
                  } else if (state is PostsLoadingState) {
                    return PostsLoaded(posts: posts);
                  } else if (state is PostsLoadedState) {
                    posts = state.posts;
                    return PostsLoaded(
                      posts: posts,
                    );
                  } else if (state is PostsLocalStorage) {
                    posts = LocalStorage.get();
                    return PostsLoaded(posts: posts);
                  } else {
                    return PostsError(
                        error: (state as PostsErrorState).error,
                        isConnected: true);
                  }
                },
              ),
            ),
          ),
        ));
  }

  void _onRefresh() async {
    _postID = 4;
    ref
        .read(postsNotifierProvider.notifier)
        .getPosts(refreshController: _refreshController, refresh: true);
    wentOffline = false;
  }

  void _onLoading({List<Posts>? posts}) async {
    wentOffline ? _postID = LocalStorage.getLastPost.id! : _postID = _postID;
    _postID += 3;
    ref.read(postsNotifierProvider.notifier).getPosts(
        refresh: false,
        oldPosts: posts,
        postID: _postID,
        refreshController: _refreshController);
    wentOffline = false;
  }

  void offline() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
        "You are offline!",
        style: TextStyle(color: Colors.black),
      ),
      backgroundColor: Colors.red,
    ));
    ref.read(postsNotifierProvider.notifier).wentOffline();
    wentOffline = true;
  }

  void online() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
        "You are back online!",
      ),
      backgroundColor: Color.fromARGB(255, 79, 255, 0),
    ));
    ref.read(postsNotifierProvider.notifier).backOnline();
  }
}
