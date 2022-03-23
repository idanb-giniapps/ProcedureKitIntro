//
//  Procedures.swift
//  ProcedureKitIntro
//
//  Created by Idan Birman on 22/03/2022.
//

import Foundation
import ProcedureKit

/// ProcedureKit is a Swift framework inspired by WWDC 2015 Advanced NSOperations session.
/// It provides a framework to manage and synchronize asynchronous, parallel operations.
///
/// **BEFORE YOU CONTINUE**, please go watch the talk: https://developer.apple.com/videos/play/wwdc2015/226/

// MARK: - Mock Error enum Definition

enum MyError: Error {
    case invalidInput
    case serverError
    case parsingError
    case unknown
}

// MARK: - ProcedureQueue

/// Definition of the `ProcedureQueue` that will be used for the demo. more on that later.
let procedureQueue = ProcedureQueue()

// MARK: - Basic Procedure
// definition
class SayHelloProcedure: Procedure {
    
    let personsName: String
    
    init(personsName: String) {
        self.personsName = personsName
        super.init()
    }
    
    // override execute but don't call super.execute(). this is where we define what the procedure does.
    override func execute() {
        
        if personsName.isEmpty {
            print("cancelling due to invalid input")
            cancel(with: MyError.invalidInput)
            finish(with: MyError.invalidInput)
            return
        }
        
        print("👋 Hello, \(personsName)")
        
        finish() // must be called by any subclass of Procedure
    }
}

// usage
func sayHello(to name: String) {
    let sayHelloProcedure = SayHelloProcedure(personsName: name)
    
    sayHelloProcedure.addDidFinishBlockObserver { procedure, error in
        
        if let error = error {
            print(error)
            return
        }
        
        print("Said hello to \(procedure.personsName)")
    }
    
    sayHelloProcedure.addDidCancelBlockObserver { procedure, error in
        print("\(procedure) was cancelled")
    }
    
    procedureQueue.addOperation(sayHelloProcedure)
}

/// Key points
///  - Subclass `Procedure`
///  - `finish()` must *always* be called. even if the procedure is cancelled.
///  - We never call `execute()` directly. it is called indirectly by adding the procedure to a `ProcedureQueue`
///  - We can react to procedure lifecycle events such as `finish` and `cancel` by adding a block observer.
///  - Run the app and tap the "Say Hello" button and look at the order of prints. take a look at `ViewController.swift` to see what each button does.

// MARK: - Dependencies

/// A powerful feature of Procedures is to define dependencies.
/// We can use dependencies to dictate the order in which procedures are executed.

// Example

func sayHelloToAliceAndBob() {
    let helloAlice = SayHelloProcedure(personsName: "Alice")
    let helloBob = SayHelloProcedure(personsName: "Bob")
    
    helloBob.addDependency(helloAlice)
    
    // the line below will cause a deadlock
//    helloAlice.addDependency(helloBob)
        
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
        procedureQueue.addOperation(helloAlice)
    }
}

/// Key points
/// - We define the dependencies before adding the procedures to a queue
/// - even though `helloBob` is added to the queue before `helloAlice`, and `helloAlice` is added after a significant delay, `helloAlice` will execute first.
/// - Dependencies are not limited by queues. if `ProcedureB` depends on `ProcedureA` and `ProcedureB` is added to `queue1` and `ProcedureA` is added to `queue2`, `ProcedureB` will not execute until `ProcedureA` is finished.
/// - We must watch out for deadlocks when working with dependencies. if `A` depends and `B` and `B` depends on `A`, both procedures will wait for the other one to finish and the queue will be suspended forever.


// MARK: - Concurrency

/// be default,  a `ProcedureQueue` is serial, meaning it can only execute one procedure at the time.
/// However, we can change that by modifying the `maxConcurrentOperationCount` property of the queue, e.g.:

func sayHelloToABunchOfPeople() {
    let names = ["Alice", "Bob", "Carl", "Dan", "Elliot", "Fiona", "Gloria"]
    
    let procedures = names.map { name -> Procedure in
        let procedure = SayHelloProcedure(personsName: name)
        procedure.log.enabled = false /// the built is logger provided by `ProcedureKit` can really clutter the console. it can be disabled like so.
        return procedure
    }
    
    // the line below tells the queue that it may execute up to 5 operations in parallel.
    procedureQueue.maxConcurrentOperationCount = 5
    
    procedureQueue.addOperations(procedures)
}

/// Key points
/// - The order in which the operations are added to a *concurrent* queue **does not** dictate the order of execution.
///  if you run the app and tap "Say Hello to a Bunch of People" button multiple times you will see that the order of execution is inconsistent.
/// However, if the queue is serial and no dependencies are set then the order of addition does in fact determine the order of execution,
/// that's because only one procedure can execute at a time and without dependencies, `execute()` is called as soon as the procedure is added to a queue.
/// a Good practice would be to rely on dependencies if the order of execution is important.

// MARK: - Group Procedures

/// Sometimes, we have a a group of procedures that we always wish to execute together.
/// A classic example would be a procedure that makes a network request and a procedure that parses data from a network request to a concrete type.
/// Or maybe we just want to know when a group of procedures all finished executing.
/// This is where `GroupProcedure` comes in.

class SayHelloToAliceAndBobGroupProcedure: GroupProcedure
{
    init() {
        let helloAlice  = SayHelloProcedure(personsName: "Alice")
        let helloBob    = SayHelloProcedure(personsName: "Bob")
        
        helloBob.addDependency(helloAlice) // ensure that we always say hello to Alice and only then to Bob.
        
        super.init(operations: [helloAlice, helloBob])
    }
    
    override func child(_ child: Procedure, willFinishWithError childError: Error?) {
        super.child(child, willFinishWithError: childError)
        
        // here we can do stuff when individual child procedure finishes
    }
}

// usage
func sayHelloToAliceAndBobWithGroupProcedure() {
    let groupProcedure = SayHelloToAliceAndBobGroupProcedure()
    
    groupProcedure.addDidFinishBlockObserver { procedure, error in
        if let error = error {
            print(error)
            return
        }
        
        print("Finished saying hello to Alice and Bob")
    }
    
    procedureQueue.addOperation(groupProcedure)
}

/// Key points
/// - `GroupProcedure` is a subclass of `Procedure`. it can do all the things a procedure can do, it can have block observers, dependencies etc.
/// - Group Procedures have an underlying queue.
/// - We subclass `GroupProcedure`
/// - We do not call `finish()` on a group procedure. it is finished when all children are finished. Calling `finish()` on a group procedure will trigger an assertion failure.
/// - If one child finished with error, the entire group procedure will finish with the same error.
/// - Illustration of a group procedure with 4 child procedures in a queue with a preceding and a subsequent procedures:
///
///
///         ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
///         │             │      │ ┌───┐ ┌───┐ │      │             │
///         │             │      │ │   │ │   │ │      │             │
///         │             │  ►   │ └───┘ └───┘ │   ►  │             │
///         │             │      │ ┌───┐ ┌───┐ │      │             │
///         │             │      │ │   │ │   │ │      │             │
///         │             │      │ └───┘ └───┘ │      │             │
///         └─────────────┘      └─────────────┘      └─────────────┘

// MARK: - Input and Output

/// Sometimes we might need a procedure to produce and output or receive and input. `ProcedureKit` provides us with a native API to achieve just that.

// MARK: Input
/// To define input for a procedure, we need to conform to the `InputProcedure` protocol.
/// it has 2 simple requirements
/// 1. define the type of input
/// 2. provided a readwrite variable of type `Pending` wrapping the type of input defined.
/// `Pending` is an enum with 2 cases: `.pending` and `.ready(T)`

/// creation
class SquareANumberInputProcedure: Procedure, InputProcedure {
    typealias Input = Int
    
    var input: Pending<Input> = .pending
    
    override func execute() {
        
        guard let numberToSquare = input.value else {
            /// this will happen if `input` is `.pending`.
            cancel(with: MyError.invalidInput)
            finish(with: MyError.invalidInput)
            return
        }
        
        print("\(numberToSquare)² = \(numberToSquare * numberToSquare)")
        finish()
    }
}

///usage
func useSquareANumberInputProcedure(number: Int) {
    let procedure = SquareANumberInputProcedure()
    
    procedure.input = .ready(number)
    
    procedureQueue.addOperation(procedure)
}

// MARK: Output
/// defining an output procedure is very similar, we need to conform to the `OutputProcedure` protocol. it has 2 requirements:
/// 1. define the output type
/// 2. declare a readwrite variable of type `Pending` wrapping a `ProcedureResult` wrapping the output type.
/// `ProcedureResult` is the same as a Swift native `Result` type, an enum with 2 cases, one to represent success with some wrapped value and another one to represent a failure with some error.

/// creation
class SquareANumberOutputProcedure: Procedure, OutputProcedure {
    typealias Output = Int
    
    var output: Pending<ProcedureResult<Output>> = .pending
    
    let numberToSquare: Int
    
    init(_ number: Int) {
        self.numberToSquare = number
        super.init()
    }
    
    override func execute() {
        /// calling `finish(withResult:)` will set `output` to whatever is passed to result and call `finish(with: output.error)`
        /// if `result` is `.success` then error is nil, otherwise `result` is `.failure` and the error passed is the associated value.
        finish(withResult: .success(numberToSquare * numberToSquare))
    }
}

/// usage
private func useSquareANumberOutputProcedure(number: Int,
                                             completion: @escaping (SquareANumberOutputProcedure.Output?) -> Void) {
    let procedure = SquareANumberOutputProcedure(5)
    
    procedure.addDidFinishBlockObserver { procedure, error in
        if let error = error {
            print(error)
            completion(nil)
            return
        }
        
        let procedureResult = procedure
            .output /// accessing the procedure's `output` property
            .value? /// accessing the `Pending` value convenience computed property. `nil` if `.pending`
            .value /// accessing `ProcedureResult`'s convenience `value` property. `nil` if not `.success` or associated value is `nil`
        
        completion(procedureResult)
    }
    
    procedureQueue.addOperation(procedure)
}

/// Using the `InputProcedure` and `OutputProcedure` may seem over-complicated at first.
/// However, A good practice is to treat Procedures as "logical building blocks".
/// We probably want to mix and match different ones throughout the project to implement complex business logic.
/// If we have a procedure that does network requests we probably want to use it all over the place with different inputs.
/// Having a uniform way of defining input and output allows us to mix and match procedures without the procedures needing to know one another.
///

// MARK: - Summarizing Example
/// let's look at an example.
/// we have a network request that returns a random integer, we need to get that integer and compute the square of it.
///  Using procedures, this can be accomplish like so:
///  1. create a procedure that makes the network request and outputs the data
///  2. create a procedure that takes data as an input, parses an `Int` and outputs it
///  3. create a procedure that takes `Int` as an input and outputs the square of it.
///  4. create a group procedure that wraps it all together.

/// 1. mock network request procedure
class MockNetworkRequestProcedure: Procedure, OutputProcedure {
    
    var output: Pending<ProcedureResult<Data>> = .pending
    
    private let delay: Int
    
    init(delay: Int) {
        self.delay = delay
        super.init()
        name = "MockNetworkRequestProcedure" // Procedures have a name. useful for debugging.
    }
    
    deinit {
        print(name!, "deinitialized")
    }
    
    override func execute() {
        
        let isSuccessful = Int.random(in: 0 ..< 100) > 5 // 5% chance to fail.
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) { [self] in
                        
            if isSuccessful {
                
                let result  = Int.random(in: 1...100)
                let data    = withUnsafeBytes(of: result) { Data($0) }
                                
                finish(withResult: .success(data))
            }
            else {
                finish(with: MyError.serverError)
            }
        }
    }
}

/// 2. parsing procedure
class ExampleParsingProcedure<T>: Procedure, InputProcedure, OutputProcedure {
    
    var input   : Pending<Data>                 = .pending
    var output  : Pending<ProcedureResult<T>>   = .pending
    
    override func execute() {
        
        guard let data = input.value else {
            finish(with: MyError.invalidInput)
            return
        }
        
        let result = data.withUnsafeBytes { $0.load(as: T.self) }
        
        finish(withResult: .success(result))
    }
}

/// 3. square procedure
class SquareANumberProcedure: Procedure, InputProcedure, OutputProcedure {
    
    var input: Pending<Int>                     = .pending
    var output: Pending<ProcedureResult<Int>>   = .pending
    
    override func execute() {
        
        guard let numberToSquare = input.value else {
            finish(with: MyError.invalidInput)
            return
        }
        
        let result = ProcedureResult.success(numberToSquare * numberToSquare)
        
        finish(withResult: result)
    }
}

/// 4. group procedure
class SquareARandomNumberGroupProcedure: GroupProcedure, OutputProcedure {
    
    var output: Pending<ProcedureResult<Int>> = .pending
    
    private let mockRequestProcedure    : MockNetworkRequestProcedure
    private let parseProcedure          : ExampleParsingProcedure<Int>
    private let squareNumberProcedure   : SquareANumberProcedure
    
    init(delay: Int) {
        
        self.mockRequestProcedure    = MockNetworkRequestProcedure(delay: delay)
        self.parseProcedure          = ExampleParsingProcedure<Int>()
        self.squareNumberProcedure   = SquareANumberProcedure()
        
        parseProcedure.addDependency(mockRequestProcedure)
        squareNumberProcedure.addDependency(parseProcedure)
        
        super.init(operations: [mockRequestProcedure, parseProcedure, squareNumberProcedure])
        
        /// `bind(from:)` binds the output of the output procedure calling the method to the output procedure passed as a parameter one way.
        /// when we write `procedureA.bind(from: procedureB)` we basically say "when the `output` of `procedureB` is set to, set the `output` of `procedureA` to the `output` of `procedureB"`
        /// That only works if both procedures are `OutputProcedures` and their `Output` is of the same type
        ///
        /// `bind(to:)` is the same but for `InputProcedure`.
        /// when we write `procedureA.bind(to: procedureB)` we are basically saying "when the `input` of `procedureA` is set, set the `input` of `procedureB` to the `input` of `procedureA`"
        bind(from: squareNumberProcedure)
    }
    
    override func child(_ child: Procedure,
                        willFinishWithError childError: Error?) {
        
        super.child(child, willFinishWithError: childError)
        
        if let childError = childError {
            cancel(with: childError)
            return
        }
        
        if child === mockRequestProcedure {
            let data = mockRequestProcedure.output.value!.value! // force unwrapping is probably ok because we know that no error has occurred, but in a production app you might want to handle that with a little more grace.
            parseProcedure.input = .ready(data)
        }
        else if child === parseProcedure {
            let number = parseProcedure.output.value!.value!
            squareNumberProcedure.input = .ready(number)
        }
    }
}

// usage
func squareARandomNumber() {
    let groupProcedure = SquareARandomNumberGroupProcedure(delay: 3)
    
    groupProcedure.addDidFinishBlockObserver { procedure, error in
        
        if let error = error {
            print(error)
            return
        }
        
        if let result = procedure.output.value?.value {
            let number = Int(sqrt(Double(result)))
            print("\(number)² = \(result)")
        }
        else {
            print("Couldn't get output from procedure")
        }
    }
    
    procedureQueue.addOperation(groupProcedure)
}
