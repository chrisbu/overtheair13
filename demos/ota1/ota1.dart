library ota1;

import 'dart:html';

getMessage(String str) => '$str Rocks';

main() {
  var button = query('#myButton');
  var myDiv = query('#myDiv');
  button.onClick.listen((e) {
    var msg = getMessage('Dart');
    myDiv.text = msg;
  });
}
