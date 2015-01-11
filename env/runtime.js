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

  function find_class_member(klass, key){
    var value = klass.$members[key];
    if(value === null || value === undefined) {
      throw "cannot find class member " + key
    }
    return value
  }

  function get_class_member(klass, key){
    return find_class_member(klass, key)
  }

  function get_instance_bounded_member(obj, key){
    var value = find_class_member(obj.$class, key)
    var bound = function(){
      value.apply(undefined, fun_args(obj, arguments))
    }
    return bound
  }

  function get(obj, key){
    if(obj === undefined) {
      throw "fatal error, obj should not undefined"
    } else {
      var klass = obj.$class
      if (klass === Class) {
         return get_class_member(obj, key)
      } else {
         return get_instance_bounded_member(obj, key)
      }
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
    klass.$class = Class
    klass.prototype.$class = klass
    classes[name] = klass
  }

  function Class(){}
  var object = function(){};
  object.$class = Class
  object.prototype.$class = object

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
    var klass = function(){
      var self = _init_obj(this)
      this.$init.apply(undefined, fun_args(self, arguments))
    }
    ancestors = ancestors || basic_ancestors
    setup_class(name, klass, ancestors)
    return klass
  }
  env.new_class = new_class

  function def(klass, name, fun){
    klass.prototype[name] = fun
    klass.$members[name] = fun
  }
  env.def = def

  function fun_args(self, args){
    var result = Array.prototype.slice.call(args);
    result.unshift(self)
    return result
  }

  var hash_class = new_class("Hash", basic_ancestors)
  hash_class.prototype["$[]"] = function(key){
    var keys = this._keys
    for(var i = 0; i < keys.length; i++){
      if(keys[i] === key) {
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

  // convert object to boolean
  function _bool(obj){
    if(obj === null || obj === false) {
      return false
    } else if(obj === undefined){
      throw "object should not undefined"
    } else {
      return true
    }
  }

  env._bool = _bool

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
