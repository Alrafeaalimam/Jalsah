import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:printing/printing_web.dart';
import 'package:web/web.dart' as web;

void ensureWebPrintingInitialized() {
  try {
    PrintingPlugin.registerWith(webPluginRegistrar);
  } catch (_) {}
}

Future<bool> downloadPdfOnWeb(Uint8List bytes, String filename) async {
  try {
    ensureWebPrintingInitialized();
    final pdfFile = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final pdfUrl = web.URL.createObjectURL(pdfFile);
    final doc = web.window.document;
    final link = web.HTMLAnchorElement()..href = pdfUrl;
    link.download = filename;
    doc.body?.append(link);
    link.click();
    link.remove();
    web.URL.revokeObjectURL(pdfUrl);
    return true;
  } catch (e) {
    return false;
  }
}
