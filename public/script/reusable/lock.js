function Lock() {
  this.locked = false;
  this.lockTime = 1000;
}

Lock.prototype.lock = function() {
  this.locked = true;
};

Lock.prototype.timedUnlock = function(...args) {
  var lock = this;
  var fn = args[0];
  setTimeout(() => { lock.unlock(); if (fn) fn(); }, this.lockTime);
};

Lock.prototype.unlock = function() {
  this.locked = false;
};

