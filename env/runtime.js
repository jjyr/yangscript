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

  function get_class_member(obj, key){
    var value = obj.$class.$members[key];
    if(value === null || value === undefined) {
      throw "cannot find class member " + key
    } else {
      var bound = function(){
        value.apply(undefined, fun_args(obj, arguments))
      }
      return bound
    }
  }

  function get(obj, key){
    if(obj === undefined) {
      throw "fatal error, obj should not undefined"
    } else {
      // var klass = obj.$class
      // if (klass === Class) {
      //   get_class_key(obj, key)
      // } else {
      return get_class_member(obj, key)
      //}
    }
  }
  env.get_attribute = get

  function set_instance_var(obj, key, value){
    obj._instance_variables[key] = value
  }
  env.set_instance_var = set_instance_var

  function get_instance_var(obj, key){
    return obj._instance_variables[key]
  }
  env.get_instance_var = get_instance_var

  function setup_class(name, klass,  ancestors){
    if(classes[name]) {
      throw "class " + name + "already defined."
    }
    klass.$name = name;
    klass.$ancestors = ancestors;
    klass.$members = {}
    klass.prototype.$class = klass
    classes[name] = klass
  }

  function Class(){}
  var object = function(){};
  object.$class = Class
  object.prototype.$class = Class

  setup_class('Object', object, []);
  //Number.hehe
  //class -> {$new.., $to_s, $hello}
  //A().to_s
  // a = A()
  // a -> {members:{}, class:A}
  // $scope.get(a).get(new)
  basic_ancestors = [object]
  setup_class("Array", Array, basic_ancestors)
  Array.prototype["$[]"] = function(index){return this[index]}
  setup_class("Boolean", Boolean, basic_ancestors)
  setup_class("Number", Number, basic_ancestors)
  setup_class("String", Array, basic_ancestors)
  setup_class("Function", Function, basic_ancestors)

  function new_class(name, ancestors){
    var klass = function(){this.$init(_init_obj(this))}
    ancestors = ancestors || basic_ancestors
    setup_class(name, klass, ancestors)
    return klass
  }
  env.new_class = new_class

  function defun(klass, name, fun){
    klass.prototype[name] = fun
    klass.$members[name] = fun
  }
  env.defun = defun

  function fun_args(self, args){
    var result = Array.prototype.slice.call(args);
    result.unshift(self)
    return result
  }

  var hash_class = new_class("Hash", basic_ancestors)
  hash_class.prototype["$[]"] = function(key){
    var keys = this._keys
    for(var i = 0; i < keys.length; i++){
      if(keys[i] == key) {
        return this._hash_obj[key]
      }
    }
    throw "cannot find key: " + key
  }

  //object basic init
  function _init_obj(obj){
    obj._instance_variables = {}
    return obj;
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
