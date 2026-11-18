#pragma once
#include <cstdint>
#include <deque>
#include <optional>

// No OBS calls here. The host validates scene identity and visibility before tick.
class RoundEngine {
public:
 enum class State { Stopped, Running, Paused };
 State state = State::Stopped;
 bool dry = true;
 std::optional<int> round;
 std::deque<std::int64_t> due;
 static constexpr std::int64_t delay = 2000;
 void baseline() { round.reset(); due.clear(); }
 void start() { baseline(); state = State::Running; }
 void stop() { baseline(); state = State::Stopped; }
 void pause() { if (state == State::Running) { baseline(); state = State::Paused; } }
 void resume() { if (state == State::Paused) { baseline(); state = State::Running; } }
 void disconnect() { baseline(); }
 void setDry(bool value) { dry = value; baseline(); }
 // Invalid data, rollback, or a missed interval cannot cause catch-up switches.
 bool observe(int value, std::int64_t now) {
   if (state != State::Running || value < 0) return false;
   if (!round) { round = value; return false; }
   if (value == *round) return false;
   // Without an explicit match identity a rollback could be a replay. Require
   // Start rather than allowing old rounds to trigger a second time.
   if (value < *round) { stop(); return false; }
   if (value - *round != 1) { baseline(); round = value; return false; }
   round = value;
   // Backlog is unsafe on air: preserve at most one switch in flight.
   if (!due.empty()) { due.clear(); return false; }
   due.push_back(now + delay); return true;
 }
 bool tick(std::int64_t now) {
   if (state != State::Running || due.empty() || due.front() > now) return false;
   due.pop_front(); return true;
 }
};
