import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_provider.dart';

class AuthenticatedNetworkImage
    extends ConsumerWidget {
  final String url;

  final double? width;
  final double? height;
  final BoxFit? fit;

  final Widget Function(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  )? loadingBuilder;

  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )? errorBuilder;

  const AuthenticatedNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final tokenAsync =
        ref.watch(
      accessTokenProvider,
    );

    return tokenAsync.when(
      loading: () {
        return SizedBox(
          width: width,
          height: height,
          child: const Center(
            child:
                CircularProgressIndicator(),
          ),
        );
      },
      error: (
        error,
        stackTrace,
      ) {
        debugPrint(
          '[AUTH IMAGE TOKEN ERROR] '
          '$error',
        );

        return SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
            ),
          ),
        );
      },
      data: (
        accessToken,
      ) {
        debugPrint(
          '[AUTH IMAGE] url=$url',
        );

        debugPrint(
          '[AUTH IMAGE] '
          'token=${accessToken != null}',
        );

        return Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          headers:
              accessToken == null
                  ? null
                  : {
                      'Authorization':
                          'Bearer $accessToken',
                    },
          loadingBuilder:
              loadingBuilder,
          errorBuilder:
              errorBuilder ??
                  (
                    context,
                    error,
                    stackTrace,
                  ) {
                    debugPrint(
                      '[AUTH IMAGE ERROR] '
                      'url=$url '
                      'error=$error',
                    );

                    return const Center(
                      child: Icon(
                        Icons
                            .broken_image_outlined,
                      ),
                    );
                  },
        );
      },
    );
  }
}