//
//  FollowUsersTableViewController.swift
//  QuizApp
//
//  Created by Omar Torres on 10/8/16.
//  Copyright © 2016 OmarTorres. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseStorage
import Firebase
import FirebaseAuth

class FollowUsersTableViewController: UITableViewController, UISearchResultsUpdating {
    
    @IBOutlet var followUsersTableView: UITableView!
    @IBOutlet weak var loader: UIActivityIndicatorView!
    
    let searchController = UISearchController(searchResultsController: nil)
    var usersArray = [NSDictionary?]()
    var filteredUsers = [NSDictionary?]()
    var currentUser: FIRUser?
    var otherUser: NSDictionary?
    var currentUserData: NSDictionary?
    
    var databaseRef: FIRDatabaseReference! {
        return FIRDatabase.database().reference()
    }
    
    var storageRef: FIRStorage {
        return FIRStorage.storage()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.isStatusBarHidden = false
        
        self.tabBarController?.tabBar.isHidden = true
        
        self.navigationController!.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor(colorLiteralRed: 21/255.0, green: 216/255.0, blue: 161/255.0, alpha: 1), NSFontAttributeName: UIFont(name: "Avenir Next", size: 20)!]
        
        // Disable the back button
        self.navigationItem.setHidesBackButton(true, animated: false)
        
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        definesPresentationContext = true
        tableView.tableHeaderView = searchController.searchBar
        searchController.searchBar.placeholder = "Busca"
        
        fetchUsers()
        
        // DGElasticPullToRefresh
        let loadingView = DGElasticPullToRefreshLoadingViewCircle()
        loadingView.tintColor = UIColor(colorLiteralRed: 218/255.0, green: 218/255.0, blue: 218/255.0, alpha: 1)
        tableView.dg_addPullToRefreshWithActionHandler({ [weak self] () -> Void in
            // Add logic here
            self?.tableView.reloadData()
            // Do not forget to call dg_stopLoading() at the end
            self?.tableView.dg_stopLoading()
            }, loadingView: loadingView)
        
        tableView.dg_setPullToRefreshFillColor(UIColor.white)
        tableView.dg_setPullToRefreshBackgroundColor(tableView.backgroundColor!)
        
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // UI for loader (activity indicator)
        loader.center = CGPoint(x: CGFloat(view.frame.size.width / 2), y: CGFloat(100))
    }
    
    func fetchUsers() {
        
        self.loader.startAnimating()
        
        databaseRef.child("Users").queryOrdered(byChild: "firstName").observe(.childAdded, with: { (snapshot) in
            
            let key = snapshot.key
            let snapshot = snapshot.value as? NSDictionary
            snapshot?.setValue(key, forKey: "uid")
            
            if key == self.currentUser?.uid {
                print("Same as currentUser")
            } else {
                self.usersArray.append(snapshot)
                
                // Insert the rows
                self.followUsersTableView.insertRows(at: [IndexPath(row: self.usersArray.count - 1, section: 0)], with: UITableViewRowAnimation.automatic)
                
                self.loader.stopAnimating()
            }
            
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if searchController.isActive && searchController.searchBar.text != "" {
            return filteredUsers.count
        } else {
            return self.usersArray.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "usersCell", for: indexPath) as! FollowUsersTableViewCell
        
        var user: NSDictionary?
        
        if searchController.isActive && searchController.searchBar.text != "" {
            user = filteredUsers[indexPath.row]
        } else {
            user = self.usersArray[indexPath.row]
        }
        
        // Configure the cell
        let userImgURL = user?["photoURL"] as? String
        storageRef.reference(forURL: userImgURL!).data(withMaxSize: 1 * 1024 * 1024) { (imgData, error) in
            if error == nil {
                DispatchQueue.main.async {
                    if let data = imgData {
                        cell.userImage.image = UIImage(data: data)
                    }
                }
            } else {
                print(error!.localizedDescription)
            }
        }
        
        cell.firstName.text = user?["firstName"] as? String
        cell.username.text = user?["username"] as? String
        cell.points.text = "\(user?["points"] as! Int)"
        
        let butCell = cell.followButton
        
        // Referencing to currentUser
        databaseRef.child("Users").child(self.currentUser!.uid).observe(.value, with: { (snapshot) in
            
            self.currentUserData = snapshot.value as? NSDictionary
            self.currentUserData?.setValue(self.currentUser!.uid, forKey: "uid")
            
        }) { (error) in
            print(error.localizedDescription)
        }
        
        // Referencing to otherUser
        databaseRef.child("Users").child(user?["uid"] as! String).observe(.value, with: { (snapshot) in
            
            let uid = user?["uid"] as! String
            user = snapshot.value as? NSDictionary
            user?.setValue(uid, forKey: "uid")
            
        }) { (error) in
            print(error.localizedDescription)
        }
        
        // Check if currentUser is following otherUser
        databaseRef.child("following").child(self.currentUser!.uid).child(user?["uid"] as! String).observe(.value, with: { (snapshot) in
            
            if(snapshot.exists()) {
                cell.followButton.setTitle("Dejar de seguir", for: .normal)
            } else {
                cell.followButton.setTitle("Seguir", for: .normal)
            }
            
        }) { (error) in
            print(error.localizedDescription)
        }
        
        // Assign the tap action which will be executed when the user taps the Follow button
        cell.tapAction = { (cell) in
            // Reference for the followers list
            let followersRef = "followers/\(user?["uid"] as! String)/\(self.currentUserData?["uid"] as! String)"
            
            // Reference for the following list
            let followingRef = "following/" + (self.currentUserData?["uid"] as! String) + "/" + (user?["uid"] as! String)
            
            if butCell?.titleLabel?.text == "Seguir" {
                
                let followersData = ["uid": self.currentUserData?["uid"] as! String,
                                     "firstName": self.currentUserData?["firstName"] as! String,
                                     "username": self.currentUserData?["username"] as! String,
                                     "points": self.currentUserData?["points"] as! Int,
                                     "photoURL": "\(self.currentUserData!["photoURL"]!)"] as [String : Any]
                
                let followingData = ["uid": user?["uid"] as! String,
                                     "firstName": user?["firstName"] as! String,
                                     "username": user?["username"] as! String,
                                     "points": user?["points"] as! Int,
                                     "photoURL": "\(user!["photoURL"]!)"] as [String : Any]
                
                let childUpdates = [followersRef: followersData,
                                    followingRef: followingData]
                
                self.databaseRef.updateChildValues(childUpdates)
                
                // Counting and saving the number of followings and followers
                let followersCount: Int?
                let followingCount: Int?
                
                if user?["followersCount"] == nil {
                    followersCount = 1
                } else {
                    followersCount = user?["followersCount"] as! Int + 1
                }
                
                if self.currentUserData?["followingCount"] == nil {
                    followingCount = 1
                } else {
                    followingCount = self.currentUserData?["followingCount"] as! Int + 1
                }
                
                // Saving the value of counters into followingCount field in User's Firebase node
                self.databaseRef.child("Users").child(self.currentUserData?["uid"] as! String).child("followingCount").setValue(followingCount)
                
                self.databaseRef.child("Users").child(user?["uid"] as! String).child("followersCount").setValue(followersCount!)
                
            } else {
                // Decrease the number of followings for the currentUser
                self.databaseRef.child("Users").child(self.currentUserData?["uid"] as! String).child("followingCount").setValue(self.currentUserData!["followingCount"] as! Int - 1)
                
                // Decrease the number of followrs for the otherUser
                self.databaseRef.child("Users").child(user?["uid"] as! String).child("followersCount").setValue(user!["followersCount"] as! Int - 1)
                
                // Reference for the followers list
                let followersRef = "followers/\(user?["uid"] as! String)/\(self.currentUserData?["uid"] as! String)"
                
                // Reference for the following list
                let followingRef = "following/" + (self.currentUserData?["uid"] as! String) + "/" + (user?["uid"] as! String)
                
                // Deleting the following and followers nodes
                let childUpdates = [followingRef: NSNull(), followersRef: NSNull()]
                self.databaseRef.updateChildValues(childUpdates)
                
            }
        }
        
        return cell
        
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        
        filterContent(self.searchController.searchBar.text!)
    }
    
    func filterContent(_ searchText: String) {
        self.filteredUsers = self.usersArray.filter{ user in
            let name = user!["firstName"] as? String
            
            return(name?.lowercased().contains(searchText.lowercased()))!
        }
        
        tableView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "ShowUser" {
            let showUserProfileVC = segue.destination as! UserProfileViewController
            showUserProfileVC.currentUser = self.currentUser
            
            if let indexPath = tableView.indexPathForSelectedRow {
                let user = usersArray[indexPath.row]
                showUserProfileVC.otherUser = user
            }
        }
        
    }
    
    @IBAction func comeBackAction(_ sender: AnyObject) {
        let transition = CATransition()
        transition.duration = 0.35
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
        //transition.delegate = self
        self.navigationController!.view.layer.add(transition, forKey: nil)
        self.navigationController!.isNavigationBarHidden = false
        self.navigationController!.tabBarController?.tabBar.isHidden = false
        self.navigationController?.popToRootViewController(animated: true)
    }
    
}
