// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/** Common methods used by transfomers. */
library polymer.src.transform.common;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:html5lib/dom.dart' show Document;
import 'package:html5lib/parser.dart' show HtmlParser;
import 'package:path/path.dart' as path;
import 'package:source_maps/span.dart' show Span;

/**
 * Parses an HTML file [contents] and returns a DOM-like tree. Adds emitted
 * error/warning to [logger].
 */
Document _parseHtml(String contents, String sourcePath, TransformLogger logger,
    {bool checkDocType: true}) {
  // TODO(jmesserly): make HTTP encoding configurable
  var parser = new HtmlParser(contents, encoding: 'utf8', generateSpans: true,
      sourceUrl: sourcePath);
  var document = parser.parse();

  // Note: errors aren't fatal in HTML (unless strict mode is on).
  // So just print them as warnings.
  for (var e in parser.errors) {
    if (checkDocType || e.errorCode != 'expected-doctype-but-got-start-tag') {
      logger.warning(e.message, e.span);
    }
  }
  return document;
}

Future<Document> readPrimaryAsHtml(Transform transform) {
  var asset = transform.primaryInput;
  var id = asset.id;
  return asset.readAsString().then((content) {
    return _parseHtml(content, id.path, transform.logger,
      checkDocType: isPrimaryHtml(id));
  });
}

Future<Document> readAsHtml(AssetId id, Transform transform) {
  var primaryId = transform.primaryInput.id;
  var url = (id.package == primaryId.package) ? id.path
      : assetUrlFor(id, primaryId, transform.logger, allowAssetUrl: true);
  return transform.readInputAsString(id).then((content) {
    return _parseHtml(content, url, transform.logger,
      checkDocType: isPrimaryHtml(id));
  });
}

/** Create an [AssetId] for a [url] seen in the [source] asset. */
// TODO(sigmund): delete once this is part of barback (dartbug.com/12610)
AssetId resolve(AssetId source, String url, TransformLogger logger, Span span) {
  if (url == null || url == '') return null;
  var uri = Uri.parse(url);
  var urlBuilder = path.url;
  if (uri.host != '' || uri.scheme != '' || urlBuilder.isAbsolute(url)) {
    logger.error('absolute paths not allowed: "$url"', span);
    return null;
  }

  var package;
  var targetPath;
  var segments = urlBuilder.split(url);
  if (segments[0] == 'packages') {
    if (segments.length < 3) {
      logger.error("incomplete packages/ path. It should have at least 3 "
          "segments packages/name/path-from-name's-lib-dir", span);
      return null;
    }
    package = segments[1];
    targetPath = urlBuilder.join('lib',
        urlBuilder.joinAll(segments.sublist(2)));
  } else if (segments[0] == 'assets') {
    if (segments.length < 3) {
      logger.error("incomplete assets/ path. It should have at least 3 "
          "segments assets/name/path-from-name's-asset-dir", span);
    }
    package = segments[1];
    targetPath = urlBuilder.join('asset',
        urlBuilder.joinAll(segments.sublist(2)));
  } else {
    package = source.package;
    targetPath = urlBuilder.normalize(
        urlBuilder.join(urlBuilder.dirname(source.path), url));
  }
  return new AssetId(package, targetPath);
}

/** Whether an asset with [id] is considered a primary entry point HTML file. */
bool isPrimaryHtml(AssetId id) => id.extension == '.html' &&
    // Note: [id.path] is a relative path from the root of a package.
    (id.path.startsWith('web/') || id.path.startsWith('test/'));

/**
 * Generate the import url for a file described by [id], referenced by a file
 * with [sourceId].
 */
// TODO(sigmund): this should also be in barback (dartbug.com/12610)
String assetUrlFor(AssetId id, AssetId sourceId, TransformLogger logger,
    {bool allowAssetUrl: false}) {
  // use package: and asset: urls if possible
  if (id.path.startsWith('lib/')) {
    return 'package:${id.package}/${id.path.substring(4)}';
  }

  if (id.path.startsWith('asset/')) {
    if (!allowAssetUrl) {
      logger.error("asset urls not allowed. "
          "Don't know how to refer to $id from $sourceId");
      return null;
    }
    return 'asset:${id.package}/${id.path.substring(6)}';
  }

  // Use relative urls only if it's possible.
  if (id.package != sourceId.package) {
    logger.error("don't know how to refer to $id from $sourceId");
    return null;
  }

  var builder = path.url;
  return builder.relative(builder.join('/', id.path),
      from: builder.join('/', builder.dirname(sourceId.path)));
}
