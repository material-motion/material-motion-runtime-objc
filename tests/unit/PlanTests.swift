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

class PlanTests: XCTestCase {
  
  var target:UITextView!
  var scheduler:Scheduler!
  var transaction:Transaction!
  var immediatelyEndingPlan:Plan!
  var foreverContinuous:Plan!
  var targetAlteringPlan:Plan!
  
  override func setUp() {
    super.setUp()
    target = UITextView.init()
    scheduler = Scheduler()
    transaction = Transaction()
    immediatelyEndingPlan = Emit(plan: InstantlyContinuous())
    foreverContinuous = ForeverContinuous()
    targetAlteringPlan = TargetAltering()
    target.text = ""
  }
  
  func testAddingNamedPlan() {
    transaction.add(plan: foreverContinuous, to: target, withName: "forever_continuous_plan_name")
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(scheduler.activityState == .active)
  }
  
  func testAddAndRemoveNamedPlan() {
    transaction.add(plan: immediatelyEndingPlan, to: target, withName: "common_name")
    transaction.add(plan: foreverContinuous, to: target, withName: "forever_continuous_plan_name")
    transaction.removePlan(named: "forever_continuous_plan_name", from: target)
    
    XCTAssertTrue(target.text! == "")
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(scheduler.activityState == .idle)
  }
  
  func testRemoveNamedPlanThatIsntThere() {
    transaction.add(plan: targetAlteringPlan, to: target, withName: "target_altering_plan")
    transaction.removePlan(named: "was_never_added_plan", from: target)
    
    XCTAssertTrue(target.text! == "")
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(target.text! == "delegatedadded")
    XCTAssertTrue(scheduler.activityState == .idle)
  }
  
  func testNamedPlansOverwiteOneAnother() {
    transaction.add(plan: foreverContinuous, to: target, withName: "common_name")
    transaction.add(plan: targetAlteringPlan, to: target, withName: "common_name")
    
    XCTAssertTrue(target.text! == "")
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(target.text! == "delegatedadded")
  }
  
  func testNamedPlansMakeAddAndRemoveCallbacks() {
    let firstPlan = TargetAltering()
    transaction.add(plan: firstPlan, to: target, withName: "common_name")
    transaction.removePlan(named: "common_name", from: target)
    
    XCTAssertTrue(target.text! == "")
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(target.text! == "")
  }
}

class TargetAltering: NSObject, Plan {
  
  func performerClass() -> AnyClass {
    return Performer.self
  }
  
  public func copy(with zone: NSZone? = nil) -> Any {
    return TargetAltering()
  }
  
  private class Performer: NSObject, ContinuousPerforming, NamedPlanPerforming {
    let target: Any
    required init(target: Any) {
      self.target = target
    }
    
    func add(plan: Plan, withName name: String) {
      if let unwrappedTarget = self.target as? UITextView {
        unwrappedTarget.text = unwrappedTarget.text + "added"
      }
    }
    
    func removePlan(named name: String) {
      if let unwrappedTarget = self.target as? UITextView {
        unwrappedTarget.text = unwrappedTarget.text + "removed"
      }
    }
    
    func set(isActiveTokenGenerator: IsActiveTokenGenerating) {
      if let unwrappedTarget = self.target as? UITextView {
        unwrappedTarget.text = "delegated"
      }
    }
    
    func setDelegatedPerformance(willStart: @escaping DelegatedPerformanceTokenReturnBlock,
                                 didEnd: @escaping DelegatedPerformanceTokenArgBlock) {
      let token = willStart()!
      if let unwrappedTarget = self.target as? UITextView {
        unwrappedTarget.text = "delegated"
      }
      didEnd(token)
    }
  }
}
