#include "../src/round-engine.hpp"
#include <iostream>
#include <stdexcept>
void check(bool ok, const char* what) { if (!ok) throw std::runtime_error(what); }
int main() {
 RoundEngine e;
 check(!e.observe(1,0), "stopped"); e.start();
 check(!e.observe(7,0), "baseline"); check(!e.observe(7,10), "duplicate");
 check(e.observe(8,100), "advance"); check(!e.tick(2099), "delay");
 check(e.tick(2100), "deadline"); check(!e.tick(2200), "exactly once");
 e.observe(9,2300); e.pause(); check(!e.tick(9000), "pause cancels");
 e.resume(); check(!e.observe(12,10000), "resume skips");
 e.observe(13,11000); e.stop(); check(!e.tick(14000), "stop cancels");
 e.start(); e.observe(20,0); e.observe(21,0); e.disconnect();
 check(!e.tick(3000), "disconnect cancels"); check(!e.observe(22,4000), "reconnect baseline");
 check(!e.observe(19,5000), "rollback"); check(!e.observe(25,5000), "jump");
 e.observe(26,6000); e.setDry(false); check(!e.tick(9000), "mode cancels");
 e.observe(30,9000); check(e.observe(31,10000), "first pending");
 check(!e.observe(32,10001), "backlog"); check(!e.tick(14000), "no burst");
 check(e.observe(33,14000), "recovers"); check(e.tick(16000), "next works");
 std::cout << "PASS: 19 baseline/delay/duplicate/pause/stop/reconnect/reset/backlog checks\n";
}
