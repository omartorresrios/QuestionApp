//
//  ViewController.swift
//  QuizApp
//
//  Created by Omar Torres on 9/17/16.
//  Copyright © 2016 OmarTorres. All rights reserved.
//

import UIKit
import FirebaseStorage
import FirebaseAuth
import FirebaseDatabase
import JDStatusBarNotification

class FeedQuestionsTableViewController: UITableViewController {
    
    var databaseRef: FIRDatabaseReference! {
        return FIRDatabase.database().reference()
    }
    
    var storageRef: FIRStorage!{
        return FIRStorage.storage()
    }
    
    @IBOutlet weak var loader: UIActivityIndicatorView!
    
    var questionsFeedArray = [Question]()
    var currentUser: AnyObject?
    var user: FIRUser?
    var selectedQuestion: Question!
    var otherUser: NSDictionary?
    var questionKey: String!
    var newQuestion: Question!
    var messageView: UIView!
    var messageLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.isStatusBarHidden = false
        
        self.currentUser = FIRAuth.auth()?.currentUser
        
        // Create message view and label programmatically
        messageView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 667))
        messageLabel = UILabel(frame: CGRect(x: 8, y: view.frame.height / 8, width: view.frame.width, height: 21))
        
        self.tableView.backgroundColor = UIColor.white
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 213
        self.tableView.allowsMultipleSelectionDuringEditing = true
        
        fetchQuestions()
        
//        // Movements for UIToolbar transparency
//        let bgImageColor = UIColor.white.withAlphaComponent(0.7)
//        navigationController?.toolbar.setBackgroundImage(onePixelImageWithColor(bgImageColor), forToolbarPosition: UIBarPosition.bottom, barMetrics: UIBarMetrics.default)
        
        // DGElasticPullToRefresh
        let loadingView = DGElasticPullToRefreshLoadingViewCircle()
        loadingView.tintColor = UIColor(red: 78/255.0, green: 221/255.0, blue: 200/255.0, alpha: 1.0)
        tableView.dg_addPullToRefreshWithActionHandler({ [weak self] () -> Void in
            self?.tableView.reloadData()
            // Do not forget to call dg_stopLoading() at the end
            self?.tableView.dg_stopLoading()
            }, loadingView: loadingView)
        
        tableView.dg_setPullToRefreshFillColor(UIColor(red: 57/255.0, green: 67/255.0, blue: 89/255.0, alpha: 1.0))
        tableView.dg_setPullToRefreshBackgroundColor(tableView.backgroundColor!)
        
        navigationController?.navigationBar.barTintColor = UIColor.white
        
    }
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        ///self.loader.center = self.view.center
        
        // Show the bottom toolbar
        //navigationController?.isToolbarHidden = false
        
    }
    
    func messageStatus() {
        self.currentUser = FIRAuth.auth()?.currentUser
        self.loader.startAnimating()
        self.databaseRef.child("Users").child(self.currentUser!.uid).child("Feed").observe(.value, with: { (snapshot) in
                
            if snapshot.exists() {
                self.loader.stopAnimating()
                // Remove message from view
                self.messageView.removeFromSuperview()
                self.messageLabel.removeFromSuperview()
            } else {
                self.loader.stopAnimating()
                // Show message in view
                self.messageLabel.textAlignment = .center
                self.messageLabel.text = "No tienes preguntas! 😟"
                self.messageLabel.font = UIFont(name: "Helvetica Neue", size: 14.0)
                    
                self.view.addSubview(self.messageView)
                self.view.addSubview(self.messageLabel)
            }
        }) { (error) in
            print(error.localizedDescription)
        }
        
    }
    
    @objc fileprivate func fetchQuestions(){
        
        self.currentUser = FIRAuth.auth()?.currentUser
        
        messageStatus()
        
        // Retrieve data
        self.databaseRef.child("Questions").observe(.value, with: { (questionsSnap) in
            var newQuestionsFeedArray = [Question]()
                
            for question in questionsSnap.children {
                let newQuestion = Question(snapshot: question as! FIRDataSnapshot)
                    
                self.databaseRef.child("Users").child(self.currentUser!.uid).child("Feed").observe(.childAdded, with: { (questionsFeed) in
                    let questionKey = questionsFeed.key
                        
                    if newQuestion.questionId == questionKey {
                        newQuestionsFeedArray.insert(newQuestion, at: 0)
                    }
                    self.questionsFeedArray = newQuestionsFeedArray
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                    self.loader.stopAnimating()
                        
                })
            }
        }) { (error) in
            print(error.localizedDescription)
        }
        
            
        //UIApplication.shared.statusBarView?.backgroundColor = UIColor(colorLiteralRed: 0/255, green: 63/255, blue: 96/255, alpha: 1)
        //navigationController?.navigationBar.barTintColor = UIColor(colorLiteralRed: 0/255, green: 63/255, blue: 96/255, alpha: 1)

//        (sender.subviews[0] as UIView).tintColor = UIColor.blue
//        (sender.subviews[1] as UIView).tintColor = UIColor.red
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return questionsFeedArray.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        messageStatus()
        let question = questionsFeedArray[indexPath.row]
            
        if question.questionImageURL.isEmpty {
                
            let cell = tableView.dequeueReusableCell(withIdentifier: "questionWithText", for: indexPath) as! TextQuestionTableViewCell
            cell.configureQuestion(question)
            return cell
                
        } else {
                
            let cell = tableView.dequeueReusableCell(withIdentifier: "questionWithImage", for: indexPath) as! ImageQuestionTableViewCell
            cell.configureQuestion(question)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // Function for delete question
    func deleteBu(_ NSIndexPathData: IndexPath) {
        
        
        // delete item at indexPath
        let question = self.questionsFeedArray[(NSIndexPathData as NSIndexPath).row]
            
        if let questionKey = question.questionId {
            self.databaseRef.child("Users").child(self.currentUser!.uid).child("Feed").child(questionKey).removeValue(completionBlock: { (error, ref) in
                if error != nil {
                    print(error!.localizedDescription)
                    return
                }
                self.questionsFeedArray.remove(at: NSIndexPathData.row)
                self.tableView.deleteRows(at: [NSIndexPathData as IndexPath], with: .automatic)
                    
                self.loader.isHidden = true
                    
                JDStatusBarNotification.show(withStatus: "Pregunta eliminada!", dismissAfter: 2.0, styleName: JDStatusBarStyleDark)
            })
        }
        
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let deleteBtn = UITableViewRowAction(style: .destructive, title: "Eliminar") { (action, indexPath) in
            self.deleteBu(indexPath as IndexPath)
        }
        
        UIButton.appearance().setTitleColor(UIColor.red, for: UIControlState.normal)
        deleteBtn.backgroundColor = UIColor.white
        
        return [deleteBtn]
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "addCommentFeed", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addCommentFeed" {
            let vc = segue.destination as! CommentViewController
            let indexPath = tableView.indexPathForSelectedRow!
            vc.selectedQuestion = questionsFeedArray[(indexPath.row)]
        }
        
        if segue.identifier == "findUserSegue" {
            let showFollowUsersTVC = segue.destination as! FollowUsersTableViewController
            showFollowUsersTVC.currentUser = self.currentUser as? FIRUser
        }
    }
    
    // Make UIToolbar Transparency
    func onePixelImageWithColor(_ color : UIColor) -> UIImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        context!.setFillColor(color.cgColor)
        context!.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let image = UIImage(cgImage: context!.makeImage()!)
        return image
    }
}
//
//extension UIApplication {
//    var statusBarView: UIView? {
//        return value(forKey: "statusBar") as? UIView
//    }
//}