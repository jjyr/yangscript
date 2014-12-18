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

  function setup_native_class(name, klass, ancestors){
    if(classes[name]) {
      throw "class " + name + "already defined."
    }
    klass.$name = name;
    klass.$ancestors = ancestors;
    klass.prototype.$class = klass
    classes[name] = klass
  }

  function Class(){}
  var object = function(){};
  object.$class = Class
  setup_native_class('Object', object, []);
  //Number.hehe
  //class -> {$new.., $to_s, $hello}
  //A().to_s
  // a = A()
  // a -> {members:{}, class:A}
  // $scope.get(a).get(new)
  basic_ancestors = [object]
  setup_native_class("Array", Array, basic_ancestors)
  Array.prototype["$[]"] = function(index){return this[index]}
  setup_native_class("Boolean", Boolean, basic_ancestors)
  setup_native_class("Number", Number, basic_ancestors)
  setup_native_class("String", Array, basic_ancestors)
  setup_native_class("Function", Function, basic_ancestors)

  function new_class(name, ancestors){
    var klass = function(){}
    setup_native_class(name, klass, ancestors)
    return klass
  }

  var hash_class = new_class("Hash", basic_ancestors)
  hash_class.prototype["$[]"] = function(index){return this._hash_obj[index]}

  // convert js object to yangscript hash
  function _hash(obj){
    new_obj = new hash_class()
    new_obj._hash_obj = obj
    return new_obj
  }

  env._hash = _hash

  global.yangscript = env;
})(this);
