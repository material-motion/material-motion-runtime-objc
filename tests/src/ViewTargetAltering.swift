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

import Foundation
import MaterialMotionRuntime
import UIKit

public class ViewTargetAltering: NSObject, NamedPlan {

  public func performerClass() -> AnyClass {
    return Performer.self
  }

  public func copy(with zone: NSZone? = nil) -> Any {
    return ViewTargetAltering()
  }

  private class Performer: NSObject, NamedPlanPerforming {
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
