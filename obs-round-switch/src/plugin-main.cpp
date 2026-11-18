// SPDX-License-Identifier: GPL-2.0-or-later
#include <obs-module.h>
#include <obs-frontend-api.h>
#include <QApplication>
#include <QCheckBox>
#include <QDialog>
#include <QElapsedTimer>
#include <QFile>
#include <QLabel>
#include <QMessageBox>
#include <QPushButton>
#include <QTextEdit>
#include <QTextDocument>
#include <QTimer>
#include <QVBoxLayout>
#include <QString>
#include <stdexcept>
#include "round-engine.hpp"

OBS_DECLARE_MODULE()
MODULE_EXPORT const char *obs_module_description(void) { return "CourtLine Round Switch: isolated native demo"; }
MODULE_EXPORT const char *obs_module_name(void) { return "CourtLine Round Switch Demo"; }

static constexpr const char *demoName = "CourtLine Round Demo";
class Demo final : public QDialog {
public:
 RoundEngine engine;
 QString sceneUuid, aUuid, bUuid;
 int64_t aId = -1, bId = -1;
 int submitted = 1;
 bool expectedA = true, virtualA = true;
 QElapsedTimer clock;
 QTimer timer;
 QTextEdit *log;
 QLabel *status;
 QCheckBox *dry;
 bool closing = false;

 explicit Demo(QWidget *parent) : QDialog(parent) {
   setWindowTitle("CourtLine Round Switch — Demo 0.1.0"); resize(570,590);
   auto *layout = new QVBoxLayout(this);
   auto *intro = new QLabel("SIMULATED ROUNDS — no Scoreholio connection yet.\n"
      "Fixed sources: Demo A (blue) / Demo B (orange). Delay: 2 seconds.\n"
      "Use a separate portable OBS instance. Create the demo, then select\n"
      "CourtLine Round Demo in OBS before pressing Start.");
   layout->addWidget(intro);
   auto button = [&](const char *label, auto fn) {
     auto *b = new QPushButton(label); layout->addWidget(b);
     connect(b,&QPushButton::clicked,this,fn); return b;
   };
   button("Create new demo scene (does not select it)",[this]{
     if (QMessageBox::question(this,"Create isolated demo", "Create one new demo scene with two new color sources? Existing scenes will not be edited.") == QMessageBox::Yes)
       createDemo();
   });
   dry = new QCheckBox("Dry Run — log only, never change visibility"); dry->setChecked(true);
   layout->addWidget(dry);
   connect(dry,&QCheckBox::toggled,this,[this](bool v){ engine.setDry(v); virtualA=expectedA; note("Mode changed; pending switches canceled; next round is baseline."); });
   button("Start",[this]{ start(); });
   button("Stop",[this]{ stop("Stopped; pending switches canceled."); });
   button("Pause",[this]{ engine.pause(); note("Paused; pending switches canceled."); });
   button("Resume",[this]{ engine.resume(); engine.observe(submitted,clock.elapsed()); note("Resumed with current round as baseline; paused events skipped."); });
   button("Submit next simulated round",[this]{ submit(); });
   button("Repeat current round (duplicate test)",[this]{ observe(); });
   button("Simulate reconnect (discard pending, rebaseline)",[this]{ engine.disconnect(); engine.observe(submitted,clock.elapsed()); note("Reconnected; current round is baseline, no catch-up."); });
   button("Test LIVE once… (ignores Dry Run)",[this]{
     if (!validScene()) { note("Select the demo scene in Program first."); return; }
     if (QMessageBox::warning(this,"Test LIVE", "This immediately switches the two demo sources, even with Dry Run checked. Continue?",QMessageBox::Yes|QMessageBox::Cancel,QMessageBox::Cancel) != QMessageBox::Yes) return;
     stop("Manual Test: monitoring stopped and pending switches canceled.");
     if (readVisibility(expectedA)) { virtualA=expectedA; flip(false); }
   });
   status = new QLabel; layout->addWidget(status);
   log = new QTextEdit; log->setReadOnly(true); layout->addWidget(log);
   clock.start(); timer.setInterval(50);
   connect(&timer,&QTimer::timeout,this,[this]{ pulse(); }); timer.start();
   note("Stopped. Dry Run is ON by default. No settings saved and no network requests.");
 }
 bool outputActive() const { return obs_frontend_streaming_active() || obs_frontend_recording_active() || obs_frontend_virtualcam_active() || obs_frontend_replay_buffer_active(); }
 void note(const QString &s) { if (log->document()->blockCount()>200) log->clear(); log->append(s); }
 void stop(const QString &why) { engine.stop(); note(why); }
 bool createDemo() {
   if (outputActive()) { note("Demo creation blocked while an output is active."); return false; }
   obs_source_t *existing=obs_get_source_by_name(demoName);
   if (existing) { obs_source_release(existing); note("A scene/source already has the demo name. It was not changed. Use a fresh portable profile or rename that old demo."); return false; }
   obs_scene_t *scene=obs_scene_create(demoName);
   if (!scene) return false;
   sceneUuid=obs_source_get_uuid(obs_scene_get_source(scene));
   auto make=[&](const char *name, long long color, int64_t &id, QString &uuid, bool visible) {
     obs_data_t *settings=obs_data_create();
     obs_data_set_int(settings,"color",color); obs_data_set_int(settings,"width",1280); obs_data_set_int(settings,"height",720);
     obs_source_t *source=obs_source_create_private("color_source_v3",name,settings);
     obs_data_release(settings);
     if (!source) return false;
     uuid=obs_source_get_uuid(source);
     obs_sceneitem_t *item=obs_scene_add(scene,source); obs_source_release(source);
     if (!item) return false;
     id=obs_sceneitem_get_id(item); obs_sceneitem_set_visible(item,visible); return true;
   };
   bool ok=make("Round Demo A — Blue",0xFFE08020LL,aId,aUuid,true) && make("Round Demo B — Orange",0xFF2080F0LL,bId,bUuid,false);
   if (!ok) { obs_source_remove(obs_scene_get_source(scene)); sceneUuid.clear(); }
   obs_scene_release(scene);
   expectedA=virtualA=true; submitted=1;
   note(ok?"Demo created. Select CourtLine Round Demo in OBS, then Start.":"Demo creation failed. Check the OBS color-source module."); return ok;
 }
 bool validScene() {
   if (sceneUuid.isEmpty() || outputActive()) return false;
   obs_source_t *current=obs_frontend_get_current_scene();
   bool ok=current && sceneUuid==obs_source_get_uuid(current);
   obs_source_release(current); return ok;
 }
 // Find actual scene-item instances; never switch by source display name.
 bool items(obs_scene_t *scene, obs_sceneitem_t *&a, obs_sceneitem_t *&b) {
   a=obs_scene_find_sceneitem_by_id(scene,aId); b=obs_scene_find_sceneitem_by_id(scene,bId);
   return a && b && a!=b && aUuid==obs_source_get_uuid(obs_sceneitem_get_source(a)) && bUuid==obs_source_get_uuid(obs_sceneitem_get_source(b));
 }
 bool readVisibility(bool &isA) {
   obs_source_t *source=obs_get_source_by_uuid(sceneUuid.toUtf8().constData());
   obs_scene_t *scene=source?obs_scene_from_source(source):nullptr;
   obs_sceneitem_t *a=nullptr,*b=nullptr;
   bool ok=scene && items(scene,a,b) && (obs_sceneitem_visible(a)!=obs_sceneitem_visible(b));
   if (ok) isA=obs_sceneitem_visible(a);
   obs_source_release(source); return ok;
 }
 bool flip(bool pretend) {
   bool actual=false;
   if (!validScene() || !readVisibility(actual) || actual!=expectedA) { stop("Canceled: scene, source, visibility, or output state changed."); return false; }
   if (pretend) { virtualA=!virtualA; note(QString("DRY RUN: would show ")+(virtualA?"A":"B")+"; actual sources unchanged."); return true; }
   obs_source_t *source=obs_get_source_by_uuid(sceneUuid.toUtf8().constData());
   struct Change { Demo *self; bool done=false; } change{this};
   obs_scene_atomic_update(obs_scene_from_source(source),[](void *data,obs_scene_t *scene){
     auto &c=*static_cast<Change*>(data); obs_sceneitem_t *a=nullptr,*b=nullptr;
     if (!c.self->items(scene,a,b) || obs_sceneitem_visible(a)!=c.self->expectedA || obs_sceneitem_visible(b)==c.self->expectedA) return;
     obs_sceneitem_set_visible(a,!c.self->expectedA); obs_sceneitem_set_visible(b,c.self->expectedA); c.done=true;
   },&change);
   obs_source_release(source);
   if (!change.done) { stop("Source changed; no switch applied."); return false; }
   expectedA=!expectedA; virtualA=expectedA; note(QString("LIVE: showing ")+(expectedA?"A (blue)":"B (orange)")); return true;
 }
 bool start() {
   if (!validScene() || !readVisibility(expectedA)) { note("Start blocked: select demo in Program, stop outputs, and leave exactly one demo source visible."); return false; }
   virtualA=expectedA; engine.start(); engine.observe(submitted,clock.elapsed());
   note(QString("Started at round %1 (baseline; no switch).").arg(submitted)); return true;
 }
 void observe() { bool queued=engine.observe(submitted,clock.elapsed()); note(QString("Round %1 — ").arg(submitted)+(queued?"switch queued for 2 seconds.":"no switch queued (baseline, duplicate, pause, or stopped).")); }
 void submit() { ++submitted; observe(); }
 void pulse() {
   if (engine.state!=RoundEngine::State::Stopped) {
     bool actual=false;
     if (!validScene() || !readVisibility(actual) || actual!=expectedA) { stop("Monitoring stopped: Program scene/source visibility/output changed."); }
   }
   if (engine.tick(clock.elapsed())) flip(engine.dry);
   const char *state=engine.state==RoundEngine::State::Running?"Running":engine.state==RoundEngine::State::Paused?"Paused":"Stopped";
   status->setText(QString("%1 | Round %2 | Pending %3 | %4").arg(state).arg(submitted).arg(engine.due.size()).arg(engine.dry?"DRY RUN":"LIVE"));
 }
 void closeEvent(QCloseEvent *event) override { engine.stop(); QDialog::closeEvent(event); }
};

static Demo *demo=nullptr;
static void showDemo(void*) { if (!demo) demo=new Demo(static_cast<QWidget*>(obs_frontend_get_main_window())); demo->show(); demo->raise(); }
static void finishTest(bool ok,const QString &detail) {
 QFile out(QString::fromUtf8(qgetenv("COURTLINE_OBS_DEMO_SELFTEST")));
 if (out.open(QIODevice::WriteOnly)) out.write(((ok?"PASS: ":"FAIL: ")+detail+"\n").toUtf8());
 QTimer::singleShot(500,qApp,[]{qApp->quit();});
}
static void selfTest() {
 showDemo(nullptr);
 if (!demo->createDemo()) { finishTest(false,"cannot create scene"); return; }
 obs_source_t *s=obs_get_source_by_uuid(demo->sceneUuid.toUtf8().constData());
 obs_frontend_set_current_scene(s); obs_source_release(s);
 QTimer::singleShot(500,demo,[]{
   if (!demo->start()) { finishTest(false,"cannot start"); return; }
   demo->submit();
   QTimer::singleShot(2300,demo,[]{
     bool a=false;
     if (!demo->readVisibility(a)||!a) { finishTest(false,"dry run changed visibility"); return; }
     demo->dry->setChecked(false); demo->start(); demo->submit();
     QTimer::singleShot(2300,demo,[]{
       bool a=true;
       if(!demo->readVisibility(a)||a) { finishTest(false,"A to B"); return; }
       demo->observe(); // duplicate must not schedule
       if(!demo->engine.due.empty()) { finishTest(false,"duplicate queued"); return; }
       demo->submit();
       QTimer::singleShot(2300,demo,[]{
         bool a=false;
         if(!demo->readVisibility(a)||!a) { finishTest(false,"B to A"); return; }
         demo->submit(); demo->engine.pause();
         QTimer::singleShot(2300,demo,[]{
           bool a=false;
           if(!demo->readVisibility(a)||!a||!demo->engine.due.empty()) { finishTest(false,"pause cancellation"); return; }
           demo->engine.resume(); demo->engine.observe(demo->submitted,demo->clock.elapsed()); demo->submit();
           obs_scene_t *other=obs_scene_create("Unrelated self-test scene");
           obs_frontend_set_current_scene(obs_scene_get_source(other)); obs_scene_release(other);
           QTimer::singleShot(2300,demo,[]{
             bool a=false;
             const bool ok=demo->readVisibility(a)&&a&&demo->engine.state==RoundEngine::State::Stopped;
             finishTest(ok,"native OBS demo: baseline, delayed A/B alternation, dry run, duplicate, pause cancellation, Program scene cancellation");
           });
         });
       });
     });
   });
 });
}
static void event(obs_frontend_event e, void*) {
 if (e==OBS_FRONTEND_EVENT_FINISHED_LOADING && !qgetenv("COURTLINE_OBS_DEMO_SELFTEST").isEmpty()) QTimer::singleShot(1500,qApp,selfTest);
 if (demo && (e==OBS_FRONTEND_EVENT_SCENE_CHANGED || e==OBS_FRONTEND_EVENT_SCENE_COLLECTION_CHANGING || e==OBS_FRONTEND_EVENT_PROFILE_CHANGING)) demo->stop("Scene/profile changed; monitoring stopped.");
 if(e==OBS_FRONTEND_EVENT_EXIT) { delete demo; demo=nullptr; obs_frontend_remove_event_callback(event,nullptr); }
}
bool obs_module_load(void) { obs_frontend_add_tools_menu_item("CourtLine Round Switch Demo",showDemo,nullptr); obs_frontend_add_event_callback(event,nullptr); return true; }
void obs_module_unload(void) { if (demo) { delete demo; demo=nullptr; } }
