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

  // Verify that a plan committed to a scheduler is copied.
  func testPlansAreCopied() {
    let state = State()
    state.boolean = false

    let plan = ChangeBoolean(desiredBoolean: true)

    let scheduler = Scheduler()

    expectation(forNotification: TraceNotificationName.plansCommitted._rawValue as String, object: scheduler) { notification -> Bool in
      let event = notification.userInfo![TraceNotificationPayloadKey] as! SchedulerPlansCommittedTracePayload
      XCTAssertNotEqual(event.committedPlans[0] as! ChangeBoolean, plan)
      return event.committedPlans.count == 1
    }

    let transaction = Transaction()
    transaction.add(plan: plan, to: state)
    scheduler.commit(transaction: transaction)

    waitForExpectations(timeout: 0.1)
  }

  // Verify that a plan committed to a scheduler immediately executes its add(plan:) logic.
  func testAddPlanInvokedImmediately() {
    let state = State()
    state.boolean = false

    let plan = ChangeBoolean(desiredBoolean: true)

    let scheduler = Scheduler()

    let transaction = Transaction()
    transaction.add(plan: plan, to: state)
    scheduler.commit(transaction: transaction)

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

      func add(plan: Plan) {
        let testPlan = plan as! ChangeBoolean
        target.boolean = testPlan.desiredBoolean
      }
    }
  }

  // Verify that two plans of the same type creates only one performer.
  func testTwoSamePlansCreatesOnePerformer() {
    let state = State()
    state.boolean = false

    let scheduler = Scheduler()

    expectation(forNotification: TraceNotificationName.performersCreated._rawValue as String, object: scheduler) { notification -> Bool in
      let event = notification.userInfo![TraceNotificationPayloadKey] as! SchedulerPerformersCreatedTracePayload
      return event.createdPerformers.count == 1
    }

    let transaction = Transaction()
    transaction.add(plan: ChangeBoolean(desiredBoolean: true), to: state)
    transaction.add(plan: ChangeBoolean(desiredBoolean: false), to: state)
    scheduler.commit(transaction: transaction)

    waitForExpectations(timeout: 0.1)
  }

  // Verify that two plans of different types creates two performers.
  func testTwoDifferentPlansCreatesTwoPerformers() {
    let state = State()
    state.boolean = false

    let scheduler = Scheduler()

    expectation(forNotification: TraceNotificationName.performersCreated._rawValue as String, object: scheduler) { notification -> Bool in
      let event = notification.userInfo![TraceNotificationPayloadKey] as! SchedulerPerformersCreatedTracePayload
      return event.createdPerformers.count == 2
    }

    let transaction = Transaction()
    transaction.add(plan: ChangeBoolean(desiredBoolean: true), to: state)
    transaction.add(plan: InstantlyContinuous(), to: state)
    scheduler.commit(transaction: transaction)

    waitForExpectations(timeout: 0.1)
  }

  // Verify that order of plans is respected in a transaction.
  func testTwoPlansOrderIsRespected() {
    let state = State()
    state.boolean = false

    let scheduler = Scheduler()

    var transaction = Transaction()
    transaction.add(plan: ChangeBoolean(desiredBoolean: true), to: state)
    transaction.add(plan: ChangeBoolean(desiredBoolean: false), to: state)
    scheduler.commit(transaction: transaction)

    XCTAssertEqual(state.boolean, false)

    transaction = Transaction()
    transaction.add(plan: ChangeBoolean(desiredBoolean: false), to: state)
    transaction.add(plan: ChangeBoolean(desiredBoolean: true), to: state)
    scheduler.commit(transaction: transaction)

    XCTAssertEqual(state.boolean, true)
  }

  // Verify that we're unable to request a delegated performance token after the scheduler has been
  // released.
  func testPostDeallocTokenGenerationIsIgnored() {
    var scheduler: Scheduler? = Scheduler()

    let transaction = Transaction()
    let plan = HijackedIsActiveTokenGenerator()
    transaction.add(plan: plan, to: NSObject())
    scheduler!.commit(transaction: transaction)

    // Force the scheduler to be deallocated.
    scheduler = nil

    XCTAssertNil(plan.state.tokenGenerator!.generate())
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

      func add(plan: Plan) {
        let delayedDelegation = plan as! HijackedIsActiveTokenGenerator
        delayedDelegation.state.tokenGenerator = tokenGenerator
      }

      var tokenGenerator: IsActiveTokenGenerating!
      func set(isActiveTokenGenerator: IsActiveTokenGenerating) {
        tokenGenerator = isActiveTokenGenerator
      }
    }
  }

  // Verify that we're unable to request a delegated performance token after the scheduler has been
  // released.
  @available(iOS, deprecated)
  func testDelayedDelegationIsIgnored() {
    var scheduler: Scheduler? = Scheduler()

    let transaction = Transaction()
    let plan = HijackedDelegation()
    transaction.add(plan: plan, to: NSObject())
    scheduler!.commit(transaction: transaction)

    // Force the scheduler to be deallocated.
    scheduler = nil

    XCTAssertNil(plan.state.willStart!())
    plan.state.didEnd!(FakeToken()) // Should silently succeed because scheduler is gone
  }

  // A fake token for use in tests.
  @available(iOS, deprecated)
  private class FakeToken: NSObject, DelegatedPerformingToken {}

  // A plan that enables hijacking of the delegated performance token blocks.
  @available(iOS, deprecated)
  private class HijackedDelegation: NSObject, Plan {
    class State {
      var willStart: DelegatedPerformanceTokenReturnBlock?
      var didEnd: DelegatedPerformanceTokenArgBlock?
    }
    var state = State()

    func performerClass() -> AnyClass {
      return Performer.self
    }

    public func copy(with zone: NSZone? = nil) -> Any {
      let copy = HijackedDelegation()
      copy.state = state
      return copy
    }

    private class Performer: NSObject, PlanPerforming, DelegatedPerforming {
      let target: Any
      required init(target: Any) {
        self.target = target
      }

      func add(plan: Plan) {
        let delayedDelegation = plan as! HijackedDelegation
        delayedDelegation.state.willStart = willStart
        delayedDelegation.state.didEnd = didEnd
      }

      var willStart: DelegatedPerformanceTokenReturnBlock!
      var didEnd: DelegatedPerformanceTokenArgBlock!
      func setDelegatedPerformance(willStart: @escaping DelegatedPerformanceTokenReturnBlock,
                                   didEnd: @escaping DelegatedPerformanceTokenArgBlock) {
        self.willStart = willStart
        self.didEnd = didEnd
      }
    }
  }
}
