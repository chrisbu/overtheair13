// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library polymer_expressions;

import 'dart:async';
import 'dart:html';

import 'package:observe/observe.dart';

import 'eval.dart';
import 'expression.dart';
import 'parser.dart';

// TODO(justin): Investigate XSS protection
Object _classAttributeConverter(v) =>
    (v is Map) ? v.keys.where((k) => v[k] == true).join(' ') :
    (v is Iterable) ? v.join(' ') :
    v;

Object _styleAttributeConverter(v) =>
    (v is Map) ? v.keys.map((k) => '$k: ${v[k]}').join(';') :
    (v is Iterable) ? v.join(';') :
    v;

class PolymerExpressions extends BindingDelegate {

  final Map<String, Object> globals;

  PolymerExpressions({Map<String, Object> globals})
      : globals = (globals == null) ? new Map<String, Object>() : globals;

  _Binding getBinding(model, String path, name, node) {
    if (path == null) return null;
    var expr = new Parser(path).parse();
    if (model is! Scope) {
      model = new Scope(model: model, variables: globals);
    }
    if (node is Element && name == "class") {
      return new _Binding(expr, model, _classAttributeConverter);
    }
    if (node is Element && name == "style") {
      return new _Binding(expr, model, _styleAttributeConverter);
    }
    return new _Binding(expr, model);
  }

  getInstanceModel(Element template, model) {
    if (model is! Scope) {
      var _scope = new Scope(model: model, variables: globals);
      return _scope;
    }
    return model;
  }
}

class _Binding extends Object with ChangeNotifierMixin {
  static const _VALUE = const Symbol('value');

  final Scope _scope;
  final ExpressionObserver _expr;
  final _converter;
  var _value;


  _Binding(Expression expr, Scope scope, [this._converter])
      : _expr = observe(expr, scope),
        _scope = scope {
    _expr.onUpdate.listen(_setValue);
    _setValue(_expr.currentValue);
  }

  _setValue(v) {
    if (v is Comprehension) {
      // convert the Comprehension into a list of scopes with the loop
      // variable added to the scope
      _value = v.iterable.map((i) {
        var vars = new Map();
        vars[v.identifier] = i;
        Scope childScope = new Scope(parent: _scope, variables: vars);
        return childScope;
      }).toList(growable: false);
    } else {
      _value = (_converter == null) ? v : _converter(v);
    }
    notifyChange(new PropertyChangeRecord(_VALUE));
  }

  get value => _value;

  set value(v) {
    try {
      assign(_expr, v, _scope);
      notifyChange(new PropertyChangeRecord(_VALUE));
    } on EvalException catch (e) {
      // silently swallow binding errors
    }
  }

  getValueWorkaround(key) {
    if (key == _VALUE) return value;
  }

  setValueWorkaround(key, v) {
    if (key == _VALUE) value = v;
  }

}
