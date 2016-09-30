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
  var incrementerTarget:IncrementerTarget!
  var scheduler:Scheduler!
  var transaction:Transaction!
  var firstViewTargetAlteringPlan:NamedPlan!
  
  override func setUp() {
    super.setUp()
    target = UITextView()
    incrementerTarget = IncrementerTarget()
    scheduler = Scheduler()
    transaction = Transaction()
    firstViewTargetAlteringPlan = ViewTargetAltering()
    target.text = ""
  }
  
  func testAddingNamedPlan() {
    transaction.addPlan(firstViewTargetAlteringPlan, named: "common_name", to: target)
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(target.text! == "removePlanInvokedaddPlanInvoked")
  }
  
  func testAddAndRemoveNamedPlan() {
    transaction.addPlan(firstViewTargetAlteringPlan, named: "name_one", to: target)
    transaction.removePlan(named: "name_two", from: target)
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(target.text! == "removePlanInvokedaddPlanInvoked")
  }
  
  func testRemoveNamedPlanThatIsntThere() {
    transaction.addPlan(firstViewTargetAlteringPlan, named: "common_name", to: target)
    transaction.removePlan(named: "was_never_added_plan", from: target)
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(target.text! == "removePlanInvokedaddPlanInvoked")
  }
  
  func testNamedPlansOverwiteOneAnother() {
    let planA = IncrementerTargetPlan()
    let planB = IncrementerTargetPlan()
    transaction.addPlan(planA, named: "common_name", to: incrementerTarget)
    transaction.addPlan(planB, named: "common_name", to: incrementerTarget)
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(incrementerTarget.addCounter == 2)
    XCTAssertTrue(incrementerTarget.removeCounter == 2)
  }
  
  func testNamedPlansMakeAddAndRemoveCallbacks() {
    let plan = ViewTargetAltering()
    transaction.addPlan(plan, named: "one_name", to: target)
    transaction.addPlan(plan, named: "two_name", to: target)
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(target.text! == "removePlanInvokedaddPlanInvokedremovePlanInvokedaddPlanInvoked")
  }
  
  func testAddingTheSameNamedPlanTwiceToTheSameTarget() {
    let plan = IncrementerTargetPlan()
    transaction.addPlan(plan, named: "one", to: incrementerTarget)
    transaction.addPlan(plan, named: "one", to: incrementerTarget)
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(incrementerTarget.addCounter == 2)
    XCTAssertTrue(incrementerTarget.removeCounter == 2)
  }

  func testAddingTheSamePlanWithSimilarNamesToTheSameTarget() {
    let firstPlan = IncrementerTargetPlan()
    transaction.addPlan(firstPlan, named: "one", to: incrementerTarget)
    transaction.addPlan(firstPlan, named: "One", to: incrementerTarget)
    transaction.addPlan(firstPlan, named: "1", to: incrementerTarget)
    transaction.addPlan(firstPlan, named: "ONE", to: incrementerTarget)
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(incrementerTarget.addCounter == 4)
    XCTAssertTrue(incrementerTarget.removeCounter == 4)
  }
  
  func testAddingTheSameNamedPlanToDifferentTargets() {
    let firstPlan = IncrementerTargetPlan()
    let secondIncrementerTarget = IncrementerTarget()
    transaction.addPlan(firstPlan, named: "one", to: incrementerTarget)
    transaction.addPlan(firstPlan, named: "one", to: secondIncrementerTarget)
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(incrementerTarget.addCounter == 1)
    XCTAssertTrue(incrementerTarget.removeCounter == 1)
    XCTAssertTrue(secondIncrementerTarget.addCounter == 1)
    XCTAssertTrue(secondIncrementerTarget.removeCounter == 1)
  }
  
  func testNamedPlanOnlyInvokesNamedCallbacks() {
    let plan = ViewTargetAltering()
    transaction.addPlan(plan, named: "one_name", to: target)
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(target.text!.range(of: "addInvoked") == nil)
  }
  
  func testPlanOnlyInvokesPlanCallbacks() {
    let plan = RegularPlanTargetAlteringPlan()
    transaction.add(plan: plan, to: target)
    
    scheduler.commit(transaction: transaction)
    
    XCTAssertTrue(target.text!.range(of: "addPlanInvoked") == nil)
    XCTAssertTrue(target.text!.range(of: "removePlanInvoked") == nil)
  }
}

class IncrementerTarget: NSObject {
  var addCounter = 0
  var removeCounter = 0
}

class RegularPlanTargetAlteringPlan: NSObject, Plan {

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
    
    func add(plan: Plan) {
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

class IncrementerTargetPlan: NSObject, NamedPlan {
  
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

class ViewTargetAltering: NSObject, NamedPlan {
  
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
    
    func add(plan: Plan) {
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
