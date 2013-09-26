library sample;

import 'dart:html';

void main() {
  var msg = "Click Me!";

  var p = new Person();
  p.name = "Dart";

  var el = query("#sample_text_id");
  el.text = msg;
  el.onClick.listen((e) {
      el.text = greet(p, "Hello");
  });
}

String greet(Person p, String greeting) {
  var result = greeting + " " + p.name;
  return result;
}

class Person {
  String _name; // private property

  String get name => _name; // getter
  set name(value) => _name = value; // setter
}