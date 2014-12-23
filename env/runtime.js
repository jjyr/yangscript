(function(global){
  var env = {};
  var classes = {};
  env.global = global;

  function find_cls_attr(cls, attr) {
    var ancestors = cls.$ancestors
    var current = cls
    var value;
    value = current[attr]
    if(value !== undefined)
      return value
    for(var i = 0;i < ancestors.length;i++) {
      current = ancestors[i]
      value = current[attr]
      if(value !== undefined)
        return value
    }
    return undefined
  }

  function find_obj_attr(obj, attr){
    var result = {}, value;
    value = obj[attr] || find_cls_attr(obj.$class, attr)
    if(value === undefined) {
      throw "cannot find attribute " + attr
    } else {
      return value
    }
  }

  function setup_class(name, klass, ctor, ancestors){
    if(classes[name]) {
      throw "class " + name + "already defined."
    }
    klass.$name = name;
    klass.$ancestors = ancestors;
    klass.prototype.$class = klass
    classes[name] = {klass: klass, ctor: ctor}
  }

  function Class(){}
  var object = function(){};
  object.$class = Class
  object.prototype.$class = Class

  setup_class('Object', object, null, []);
  //Number.hehe
  //class -> {$new.., $to_s, $hello}
  //A().to_s
  // a = A()
  // a -> {members:{}, class:A}
  // $scope.get(a).get(new)
  basic_ancestors = [object]
  setup_class("Array", Array, null, basic_ancestors)
  Array.prototype["$[]"] = function(index){return this[index]}
  setup_class("Boolean", Boolean, null, basic_ancestors)
  setup_class("Number", Number, null, basic_ancestors)
  setup_class("String", Array, null, basic_ancestors)
  setup_class("Function", Function, null, basic_ancestors)

  function new_class(name, ancestors){
    var klass = function(){}
    var ctor = function(){return new klass()}
    ancestors = ancestors || basic_ancestors
    setup_class(name, klass, ctor, ancestors)
    return ctor
  }
  env.new_class = new_class

  var hash_ctor = new_class("Hash", basic_ancestors)
  var hash_class = classes["Hash"].klass
  hash_class.prototype["$[]"] = function(key){
    var keys = this._keys
    for(var i = 0; i < keys.length; i++){
      if(keys[i] == key) {
        return this._hash_obj[key]
      }
    }
    throw "cannot find key: " + key
  }

  // convert js object to yangscript hash
  function _hash(obj, keys){
    new_obj = hash_ctor()
    new_obj._hash_obj = obj
    new_obj._keys = keys
    return new_obj
  }

  env._hash = _hash

  global.yangscript = env;
})(this);
