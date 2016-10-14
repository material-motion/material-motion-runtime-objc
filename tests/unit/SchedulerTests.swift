/*
 Copyright 2016-present The Material Motion Authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import XCTest
import MaterialMotionRuntime

class SchedulerTests: XCTestCase {

  var target:UITextView!
  private var incrementerTarget:IncrementerTarget!
  var firstViewTargetAlteringPlan:NamedPlan!

  override func setUp() {
    super.setUp()
    target = UITextView()
    incrementerTarget = IncrementerTarget()
    firstViewTargetAlteringPlan = ViewTargetAltering()
    target.text = ""
  }

  // Verify that a plan committed to a scheduler is copied.
  func testPlansAreCopied() {
    let state = State()
    state.boolean = false

    let plan = ChangeBoolean(desiredBoolean: true)

    let scheduler = Scheduler()
    let tracer = StorageTracer()
    scheduler.addTracer(tracer)

    scheduler.addPlan(plan, to: state)

    XCTAssertEqual(tracer.addedPlans.count, 1)
    XCTAssertNotEqual(tracer.addedPlans[0] as! ChangeBoolean, plan)
  }

  // Verify that a plan committed to a scheduler immediately executes its add(plan:) logic.
  func testAddPlanInvokedImmediately() {
    let state = State()
    state.boolean = false

    let plan = ChangeBoolean(desiredBoolean: true)

    let scheduler = Scheduler()
    scheduler.addPlan(plan, to: state)

    XCTAssertEqual(state.boolean, plan.desiredBoolean)
  }

  // Simple instantiable target with a mutable boolean property.
  private class State {
    var boolean = false
  }

  private class ChangeBoolean: NSObject, Plan {
    var desiredBoolean: Bool

    init(desiredBoolean: Bool) {
      self.desiredBoolean = desiredBoolean
    }

    func performerClass() -> AnyClass {
      return Performer.self
    }

    public func copy(with zone: NSZone? = nil) -> Any {
      return ChangeBoolean(desiredBoolean: desiredBoolean)
    }

    private class Performer: NSObject, Performing, PlanPerforming {
      let target: State
      required init(target: Any) {
        self.target = target as! State
      }

      func addPlan(_ plan: Plan) {
        let testPlan = plan as! ChangeBoolean
        target.boolean = testPlan.desiredBoolean
      }
    }
  }

  private class ChangeBooleanNamedPlan: NSObject, NamedPlan {
    var desiredBoolean: Bool

    init(desiredBoolean: Bool) {
      self.desiredBoolean = desiredBoolean
    }

    func performerClass() -> AnyClass {
      return Performer.self
    }

    public func copy(with zone: NSZone? = nil) -> Any {
      return ChangeBooleanNamedPlan(desiredBoolean: desiredBoolean)
    }

    private class Performer: NSObject, Performing, NamedPlanPerforming {
      let target: State
      required init(target: Any) {
        self.target = target as! State
      }

      func addPlan(_ plan: NamedPlan, named name: String) {
        let testPlan = plan as! ChangeBooleanNamedPlan
        target.boolean = testPlan.desiredBoolean
      }

      func removePlan(named name: String) {

      }
    }
  }

  // Verify that two plans of the same type creates only one performer.
  func testTwoSamePlansCreatesOnePerformer() {
    let state = State()
    state.boolean = false

    let scheduler = Scheduler()
    let tracer = StorageTracer()
    scheduler.addTracer(tracer)

    scheduler.addPlan(ChangeBoolean(desiredBoolean: true), to: state)
    scheduler.addPlan(ChangeBoolean(desiredBoolean: false), to: state)

    XCTAssertEqual(tracer.createdPerformers.count, 1)
  }

  // Verify that two plans of different types creates two performers.
  func testTwoDifferentPlansCreatesTwoPerformers() {
    let state = State()
    state.boolean = false

    let scheduler = Scheduler()
    let tracer = StorageTracer()
    scheduler.addTracer(tracer)

    scheduler.addPlan(ChangeBoolean(desiredBoolean: true), to: state)
    scheduler.addPlan(InstantlyContinuous(), to: state)

    XCTAssertEqual(tracer.createdPerformers.count, 2)
  }

  // Verify that order of plans is respected in a scheduler.
  func testTwoPlansOrderIsRespected() {
    let state = State()
    state.boolean = false

    let scheduler = Scheduler()

    scheduler.addPlan(ChangeBoolean(desiredBoolean: true), to: state)
    scheduler.addPlan(ChangeBoolean(desiredBoolean: false), to: state)

    XCTAssertEqual(state.boolean, false)

    scheduler.addPlan(ChangeBoolean(desiredBoolean: false), to: state)
    scheduler.addPlan(ChangeBoolean(desiredBoolean: true), to: state)

    XCTAssertEqual(state.boolean, true)
  }

  // Verify that we're unable to request a delegated performance token after the scheduler has been
  // released.
  func testPostDeallocTokenGenerationIsIgnored() {
    var scheduler: Scheduler? = Scheduler()

    let plan = HijackedIsActiveTokenGenerator()
    scheduler!.addPlan(plan, to: NSObject())

    // Force the scheduler to be deallocated.
    scheduler = nil

    XCTAssertNil(plan.state.tokenGenerator!.generate())
  }

  func testAddingNamedPlan() {
    let scheduler = Scheduler()

    scheduler.addPlan(firstViewTargetAlteringPlan, named: "common_name", to: target)

    XCTAssertTrue(target.text! == "removePlanInvokedaddPlanInvoked")
  }

  func testAddAndRemoveTheSameNamedPlan() {
    let scheduler = Scheduler()

    scheduler.addPlan(firstViewTargetAlteringPlan, named: "name_one", to: target)
    scheduler.removePlan(named: "name_one", from: target)

    XCTAssertTrue(target.text! == "removePlanInvokedaddPlanInvokedremovePlanInvoked")
  }

  func testRemoveNamedPlanThatIsntThere() {
    let scheduler = Scheduler()

    scheduler.addPlan(firstViewTargetAlteringPlan, named: "common_name", to: target)
    scheduler.removePlan(named: "was_never_added_plan", from: target)

    XCTAssertTrue(target.text! == "removePlanInvokedaddPlanInvoked")
  }

  func testNamedPlansOverwiteOneAnother() {
    let scheduler = Scheduler()
    let planA = IncrementerTargetPlan()
    let planB = IncrementerTargetPlan()
    scheduler.addPlan(planA, named: "common_name", to: incrementerTarget)
    scheduler.addPlan(planB, named: "common_name", to: incrementerTarget)

    XCTAssertTrue(incrementerTarget.addCounter == 2)
    XCTAssertTrue(incrementerTarget.removeCounter == 2)
  }

  func testNamedPlansMakeAddAndRemoveCallbacks() {
    let scheduler = Scheduler()
    let plan = ViewTargetAltering()
    scheduler.addPlan(plan, named: "one_name", to: target)
    scheduler.addPlan(plan, named: "two_name", to: target)

    XCTAssertTrue(target.text! == "removePlanInvokedaddPlanInvokedremovePlanInvokedaddPlanInvoked")
  }

  func testAddingTheSameNamedPlanTwiceToTheSameTarget() {
    let scheduler = Scheduler()
    let plan = IncrementerTargetPlan()
    scheduler.addPlan(plan, named: "one", to: incrementerTarget)
    scheduler.addPlan(plan, named: "one", to: incrementerTarget)

    XCTAssertTrue(incrementerTarget.addCounter == 2)
    XCTAssertTrue(incrementerTarget.removeCounter == 2)
  }

  func testAddingTheSamePlanWithSimilarNamesToTheSameTarget() {
    let scheduler = Scheduler()
    let firstPlan = IncrementerTargetPlan()
    scheduler.addPlan(firstPlan, named: "one", to: incrementerTarget)
    scheduler.addPlan(firstPlan, named: "One", to: incrementerTarget)
    scheduler.addPlan(firstPlan, named: "1", to: incrementerTarget)
    scheduler.addPlan(firstPlan, named: "ONE", to: incrementerTarget)

    XCTAssertTrue(incrementerTarget.addCounter == 4)
    XCTAssertTrue(incrementerTarget.removeCounter == 4)
  }

  func testAddingTheSameNamedPlanToDifferentTargets() {
    let scheduler = Scheduler()
    let firstPlan = IncrementerTargetPlan()
    let secondIncrementerTarget = IncrementerTarget()
    scheduler.addPlan(firstPlan, named: "one", to: incrementerTarget)
    scheduler.addPlan(firstPlan, named: "one", to: secondIncrementerTarget)

    XCTAssertTrue(incrementerTarget.addCounter == 1)
    XCTAssertTrue(incrementerTarget.removeCounter == 1)
    XCTAssertTrue(secondIncrementerTarget.addCounter == 1)
    XCTAssertTrue(secondIncrementerTarget.removeCounter == 1)
  }

  func testNamedPlanOnlyInvokesNamedCallbacks() {
    let scheduler = Scheduler()
    let plan = ViewTargetAltering()
    scheduler.addPlan(plan, named: "one_name", to: target)

    XCTAssertTrue(target.text!.range(of: "addInvoked") == nil)
  }

  func testPlanOnlyInvokesPlanCallbacks() {
    let scheduler = Scheduler()
    let plan = RegularPlanTargetAlteringPlan()
    scheduler.addPlan(plan, to: target)

    XCTAssertTrue(target.text!.range(of: "addPlanInvoked") == nil)
    XCTAssertTrue(target.text!.range(of: "removePlanInvoked") == nil)
  }

  func testNamedPlansReusePerformers() {
    let scheduler = Scheduler()
    var numberOfCreatedPerformers = 0
    expectation(forNotification: TraceNotificationName.performersCreated._rawValue as String, object: scheduler) { notification -> Bool in
      let event = notification.userInfo![TraceNotificationPayloadKey] as! SchedulerPerformersCreatedTracePayload
      numberOfCreatedPerformers = numberOfCreatedPerformers + event.createdPerformers.count
      return numberOfCreatedPerformers == 1
    }

    scheduler.addPlan(firstViewTargetAlteringPlan, named: "name_one", to: target)
    scheduler.removePlan(named: "name_one", from: target)

    waitForExpectations(timeout: 0.1)
  }

  func testNamedPlansAreCommunicatedViaNSNotifications() {
    let scheduler = Scheduler()

    expectation(forNotification: TraceNotificationName.plansCommitted._rawValue as String, object: scheduler) { notification -> Bool in
      let event = notification.userInfo![TraceNotificationPayloadKey] as! SchedulerPlansCommittedTracePayload
      return event.committedAddPlans.count == 1 && event.committedRemovePlans.count == 1
    }

    scheduler.addPlan(firstViewTargetAlteringPlan, named: "name_one", to: target)

    waitForExpectations(timeout: 0.1)
  }

  func testNamedRemovePlansWithAddsAreNotCommunicatedViaNSNotifications() {
    let scheduler = Scheduler()

    expectation(forNotification: TraceNotificationName.plansCommitted._rawValue as String, object: scheduler) { notification -> Bool in
      let event = notification.userInfo![TraceNotificationPayloadKey] as! SchedulerPlansCommittedTracePayload
      return event.committedAddPlans.count == 1 && event.committedRemovePlans.count == 1
    }

    scheduler.addPlan(firstViewTargetAlteringPlan, named: "name_one", to: target)
    scheduler.removePlan(named: "name_one", from: target)

    waitForExpectations(timeout: 0.1)
  }

  func testNamedTestsAreRemovedOnATracer() {
    let scheduler = Scheduler()
    let tracer = NamedStorageTracer()
    scheduler.addTracer(tracer)

    scheduler.addPlan(firstViewTargetAlteringPlan, named: "name_one", to: target)
    scheduler.removePlan(named: "name_one", from: target)

    XCTAssertTrue(tracer.removedPlanNames.count == 2)
    XCTAssertTrue(tracer.removedPlanNames[0] == "name_one")
    XCTAssertTrue(tracer.removedPlanNames[1] == "name_one")
  }

  func testNamedPlansRespectTracers() {
    let differentPlan = ChangeBooleanNamedPlan(desiredBoolean:true)
    let state = State()
    let scheduler = Scheduler()
    let tracer = StorageTracer()
    scheduler.addTracer(tracer)

    scheduler.addPlan(firstViewTargetAlteringPlan, named: "name_one", to: target)
    scheduler.addPlan(differentPlan, named: "name_two", to: state)

    XCTAssertEqual(tracer.addedPlans.count, 2)
    XCTAssert(tracer.addedPlans[0] is NamedPlan)
    XCTAssert(tracer.addedPlans[1] is ChangeBooleanNamedPlan)

    XCTAssert(target.text == "removePlanInvokedaddPlanInvoked")
    XCTAssert(state.boolean)
  }

  // A plan that enables hijacking of the delegated performance token blocks.
  private class HijackedIsActiveTokenGenerator: NSObject, Plan {
    // We must store the generator in an intermediary "state" object that we can share across plan
    // copies. This breaks the separation of concerns between plans and performers and should not
    // be used in a production setting.
    class State {
      var tokenGenerator: IsActiveTokenGenerating?
    }
    var state = State()

    func performerClass() -> AnyClass {
      return Performer.self
    }

    public func copy(with zone: NSZone? = nil) -> Any {
      let copy = HijackedIsActiveTokenGenerator()
      copy.state = state
      return copy
    }

    private class Performer: NSObject, PlanPerforming, ContinuousPerforming {
      let target: Any
      required init(target: Any) {
        self.target = target
      }

      func addPlan(_ plan: Plan) {
        let delayedDelegation = plan as! HijackedIsActiveTokenGenerator
        delayedDelegation.state.tokenGenerator = tokenGenerator
      }

      var tokenGenerator: IsActiveTokenGenerating!
      func set(isActiveTokenGenerator: IsActiveTokenGenerating) {
        tokenGenerator = isActiveTokenGenerator
      }
    }
  }

  private class IncrementerTarget: NSObject {
    var addCounter = 0
    var removeCounter = 0
  }

  private class RegularPlanTargetAlteringPlan: NSObject, Plan {

    func performerClass() -> AnyClass {
      return Performer.self
    }

    public func copy(with zone: NSZone? = nil) -> Any {
      return RegularPlanTargetAlteringPlan()
    }

    private class Performer: NSObject, NamedPlanPerforming, PlanPerforming {
      let target: Any
      required init(target: Any) {
        self.target = target
      }

      func addPlan(_ plan: Plan) {
        if let unwrappedTarget = self.target as? UITextView {
          unwrappedTarget.text = unwrappedTarget.text + "addInvoked"
        }
      }

      func addPlan(_ plan: NamedPlan, named name: String) {
        if let unwrappedTarget = self.target as? UITextView {
          unwrappedTarget.text = unwrappedTarget.text + "addPlanInvoked"
        }
      }

      func removePlan(named name: String) {
        if let unwrappedTarget = self.target as? UITextView {
          unwrappedTarget.text = unwrappedTarget.text + "removePlanInvoked"
        }
      }
    }
  }

  private class IncrementerTargetPlan: NSObject, NamedPlan {

    func performerClass() -> AnyClass {
      return Performer.self
    }

    public func copy(with zone: NSZone? = nil) -> Any {
      return IncrementerTargetPlan()
    }

    private class Performer: NSObject, NamedPlanPerforming {
      let target: Any
      required init(target: Any) {
        self.target = target
      }

      func addPlan(_ plan: NamedPlan, named name: String) {
        if let unwrappedTarget = self.target as? IncrementerTarget {
          unwrappedTarget.addCounter = unwrappedTarget.addCounter + 1
        }
      }

      func removePlan(named name: String) {
        if let unwrappedTarget = self.target as? IncrementerTarget {
          unwrappedTarget.removeCounter = unwrappedTarget.removeCounter + 1
        }
      }
    }
  }

  private class ViewTargetAltering: NSObject, NamedPlan {

    func performerClass() -> AnyClass {
      return Performer.self
    }

    public func copy(with zone: NSZone? = nil) -> Any {
      return ViewTargetAltering()
    }

    private class Performer: NSObject, NamedPlanPerforming, PlanPerforming {
      let target: Any
      required init(target: Any) {
        self.target = target
      }

      func addPlan(_ plan: Plan) {
        if let unwrappedTarget = self.target as? UITextView {
          unwrappedTarget.text = unwrappedTarget.text + "addInvoked"
        }
      }

      func addPlan(_ plan: NamedPlan, named name: String) {
        if let unwrappedTarget = self.target as? UITextView {
          unwrappedTarget.text = unwrappedTarget.text + "addPlanInvoked"
        }
      }

      func removePlan(named name: String) {
        if let unwrappedTarget = self.target as? UITextView {
          unwrappedTarget.text = unwrappedTarget.text + "removePlanInvoked"
        }
      }
    }
  }
}
