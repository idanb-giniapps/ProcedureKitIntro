//
//  ViewController.swift
//  ProcedureKitIntro
//
//  Created by Idan Birman on 22/03/2022.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func didTapSayHello(_ sender: UIButton) {
        sayHello(to: "Dan") // this should finish successfully
        sayHello(to: "") // this should cancel due to invalid input
    }
    
    @IBAction func didTapSayHelloToAliceAndBob(_ sender: UIButton) {
        sayHelloToAliceAndBob()
    }
    @IBAction func didTapSayHelloToABunchOfPeople(_ sender: UIButton) {
        sayHelloToABunchOfPeople()
    }
    
    @IBAction func didTapSayHelloToAliceAndBobWithGroupProcedure(_ sender: UIButton) {
        sayHelloToAliceAndBobWithGroupProcedure()
    }
    
    @IBAction func didTapSquareANumber(_ sender: UIButton) {
        useSquareANumberInputProcedure(number: 5)
    }
    
    @IBAction func didTapSquareARandomNumber(_ sender: UIButton) {
        squareARandomNumber()
    }
}

