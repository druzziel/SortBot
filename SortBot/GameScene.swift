//
//  GameScene.swift
//  SortBot
//
//  Created by David Roth on 7/2/16.
//  Copyright © 2016 David Roth. All rights reserved.
//

import SpriteKit
import GameplayKit

// Node name constants
private let kBlackNodeName = "BlackRubbishItem"
private let kBlueNodeName = "BlueRubbishItem"
private let kGreenNodeName = "GreenRubbishItem"

private let kGarbageBinName = "garbage bin"
private let kRecycleBinName = "recycling bin"
private let kCompostBinName = "compost bin"
private let kChyronName = "chyron"

private var attributes : [NSObjectProtocol] = ["NodeColor"]
private var examples : [[NSObjectProtocol]] = [[]]
private var actions  : [NSObjectProtocol] = []

// Physics constants
let rubbishItemMask : UInt32 = 0x1 << 0;  // 1
let binMask         : UInt32 = 0x1 << 1;  // 2

// Gameplay Kit Decision Tree
var gameMoves : [String:String]? = nil

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    var entities = [GKEntity]()
    var graphs = [GKGraph]()
    var selectedNode : SKSpriteNode?
    var rubbishItem : SKSpriteNode!
    
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
    }
    
    override func sceneDidLoad() {
        self.loadRubbishItem()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        let positionInScene = touch?.location(in: self)
        if let touchedItem = self.atPoint(positionInScene!) as? SKSpriteNode {
            if touchedItem.name == kBlackNodeName ||
                touchedItem.name == kBlueNodeName ||
                touchedItem.name == kGreenNodeName {
                selectedNode = touchedItem
            }
        }
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        if (selectedNode != nil) {
            selectedNode?.position = (touch?.location(in: self))!
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.checkForDisposal()
    }
    
    //Game Functions
    
    func checkForDisposal() {
        if selectedNode != nil {
            let binNode = binForRubbishItem(item: selectedNode!)
            //let intersects : Bool = (selectedNode?.intersects(binNode))!
            let intersects : Bool = binNode.frame.contains((selectedNode?.frame)!)
            if intersects {
                // make a note that we have placed item A in bin B
                self.logDisposal(rubbishItem: selectedNode!, inBin: binNode)
                self.removeRubbishItem(item: selectedNode!)
            } else {
                let chyron = self.childNode(withName: kChyronName) as! SKSpriteNode
                if chyron.frame.contains((selectedNode?.frame)!) {
                    // get a random target
                    let targetBin = self.getLearnedBin()
                    self.move(rubbishItem: selectedNode!, toBin: targetBin)
                } else {
                    self.returnRubbishItem(item: selectedNode!)
                }
            }
        }
    }
    
    func logDisposal(rubbishItem: SKSpriteNode, inBin: SKSpriteNode) {
        let rubbishItemName = rubbishItem.name
        let binName = inBin.name
        examples.append([rubbishItemName!])
        actions.append(binName!)
    }
    
    func returnRubbishItem(item: SKSpriteNode) {
        let returnAction = SKAction.move(to: CGPoint(x: 0.0, y: 0.0), duration: 0.75)
        returnAction.timingMode = .easeInEaseOut
        item.run(returnAction)
    }
    
    func removeRubbishItem(item: SKSpriteNode) {
        let removeAction = SKAction.scale(by: 0.1, duration: 0.5)
        item.run(removeAction) {
            item.removeFromParent()
            self.selectedNode = nil
            self.loadRubbishItem()
        }
    }
    
    func binForRubbishItem(item: SKSpriteNode) -> SKSpriteNode {
        let rubbishItem = item.name
        var bin : SKSpriteNode? = SKSpriteNode()
        if rubbishItem == kBlackNodeName {
            bin = self.childNode(withName: kGarbageBinName) as? SKSpriteNode
        } else if rubbishItem == kBlueNodeName {
            bin = self.childNode(withName: kRecycleBinName) as? SKSpriteNode
        } else if rubbishItem == kGreenNodeName {
            bin = self.childNode(withName: kCompostBinName) as? SKSpriteNode
        }
        return bin!
    }
    
    func loadRubbishItem() {
        // grab a random rubbish item from the RubbishItem scene
        let rubbishItems  = SKScene(fileNamed: "RubbishItem")!.children
        let randomSource = GKShuffledDistribution(forDieWithSideCount: 3)
        let index = randomSource.nextInt() - 1
        let rubbishItem : SKSpriteNode = rubbishItems[index] as! SKSpriteNode
        rubbishItem.removeFromParent()
        self.addChild(rubbishItem)
        rubbishItem.physicsBody!.contactTestBitMask = binMask
        rubbishItem.position = CGPoint(x: 0,
                                       y: 0)
    }
    
    //Robot Controls
    func move(rubbishItem: SKSpriteNode?, toBin: SKSpriteNode?) {
        // simulate touch-and-drag of the rubbish item to the coordinates
        // of the target bin
        let targetPosition = toBin?.position
        let disposeAction = SKAction.move(to: targetPosition!, duration: 0.75)
        rubbishItem?.run(disposeAction, completion: {
            self.checkForDisposal()
        })
    }
    
    func getRandomBin() -> SKSpriteNode {
        // build a decision tree with three random actions:
        // move to recycle, move to compost, or move to trash
        // first question is bogus
        let baseQuestion = "Test?"
        let randomDecisionTree = GKDecisionTree(attribute: baseQuestion)
        let rootNode = randomDecisionTree.rootNode
        
        let trashAction = kGarbageBinName
        let recycleAction = kRecycleBinName
        let compostAction = kCompostBinName
        
        // if you forget this, it segfaults.
        // Random decision trees need a random source; it
        // won't load one for you by default.
        randomDecisionTree.randomSource = GKRandomSource()
        
        rootNode?.createBranch(withWeight: 3, attribute: trashAction)
        rootNode?.createBranch(withWeight: 3, attribute: recycleAction)
        rootNode?.createBranch(withWeight: 3, attribute: compostAction)
        
        let randomBin = randomDecisionTree.findAction(forAnswers: [:]) as! String
        
        return self.childNode(withName: randomBin) as! SKSpriteNode
        
    }
    
    func getLearnedBin() -> SKSpriteNode {
        // If you call this before correctly disposing of one of each type of item,
        // the app will crash because the decision tree will be incomplete.
        // Caveat Coder.
        let filteredExamples = examples.filter({$0.count > 0})
        let myDecisionTree = GKDecisionTree(examples: filteredExamples, actions: actions, attributes: attributes)
        let binName = myDecisionTree.findAction(forAnswers: ["NodeColor":self.selectedNode!.name!])
        return self.childNode(withName: binName as! String) as! SKSpriteNode
    }
    
}
