//
//  ViewController.swift
//  MSCP
//
//  Created by Bob Gendler on 8/19/20.
//  Copyright © 2020 Bob Gendler. All rights reserved.
//

import Cocoa
import os

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
    
    @IBOutlet weak var branchSelect: NSPopUpButton!
    @IBOutlet weak var baselineSelect: NSPopUpButton!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var complianceButton: NSButtonCell!
    
    //keep track of all the rule paths
    //keep track if the rule is clicked or not
    var ruleURLs = [URL]()
    var rulesStatus = [[String: Int]]()
    var yamlRule = rules()
    
    //load up git stuff as the UI loads
    override func viewDidAppear() {
        
        //download the repo if it doesn't exist
        if !FileManager.default.fileExists(atPath: defaultLocalRepoPath) {
            GitHelper().getRepo()
        }
        
        //list the branches and load the menus
        let branchList = GitHelper().listBranches()
        getDir()
        loadBranchSelector(branches: branchList)
        branchSelect.selectItem(withTitle: "origin/master")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
        
        //reload the table with the data
        getDir()
        tableView.reloadData()
        
    }
    
    //fills in the branch drop down
    func loadBranchSelector(branches: [String]) {
        for branch in branches {
            branchSelect.addItem(withTitle: branch)
        }
        getDir()
        tableView.reloadData()
    }
    
    
    //fills Baseline dropdown
    func loadBaselines() {
        let fm = FileManager.default
        let baselinesPath = defaultLocalRepoPath + "/baselines"
        do {
            let items = try fm.contentsOfDirectory(atPath: baselinesPath)
            
            for item in items {
                baselineSelect.addItem(withTitle: item)
            }
        } catch {
            // failed to read directory – reasons?
        }
    }
    
    //load table data
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?{
        //if a baseline is selected, get the rules for it
        if let selectedBaseline =  baselineSelect.titleOfSelectedItem {
            let baselineRules = baselines().readBaseline(baseline: selectedBaseline)

                guard let checkboxCell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "checkCell"), owner: self) as? CustomTableCell else { return nil }
                
            //if the rule in the baseline matches one in URL list, check it
                if let ruleName = ruleURLs[row].absoluteString.components(separatedBy: "/").last?.components(separatedBy: ".")[0] {
                    if baselineRules.contains(ruleName) {
                        checkboxCell.checkBox.integerValue = 1
                    } else {
                        checkboxCell.checkBox.integerValue = 0
                    }
                    checkboxCell.checkBox.title = ruleName
                    //make note of its status
                    rulesStatus.append([ruleName:checkboxCell.checkBox.integerValue])

                return checkboxCell
            }
            
        }
        
        return nil
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return ruleURLs.count
    }
    
    //if a branch is selected, load the baselines
    @IBAction func branchSelect(_ sender: NSPopUpButton) {
        if branchSelect.titleOfSelectedItem == "" {
            return
        }
        
        baselineSelect.isEnabled = true
        if let selectedItem = branchSelect.titleOfSelectedItem {
            GitHelper().getBranch(branch: selectedItem)
            loadBaselines()
            getDir()
            tableView.reloadData()
        }
        
        
        
    }
    
    //baseline selected, reload the table data
    @IBAction func baselineSelect(_ sender: Any) {
        if baselineSelect.titleOfSelectedItem == "" {
            return
        }
        tableView.reloadData()
    }
    

    // run a compliance report on all the rules selected
    @IBAction func complianceReport(_ sender: Any) {
        
        let file = "/tmp/mscp.log"
        let fileURL = URL(fileURLWithPath: file)

        var text = "I am a log message!\n"
        
        for rule in rulesStatus {
            for (key, value) in rule {
                for ruleURL in ruleURLs {
                    if ruleURL.absoluteString.contains(key) && value == 1{
                        yamlRule.readRules(ruleURL: ruleURL)
                        if yamlRule.tags.contains("manual") || yamlRule.tags.contains("inherent") || yamlRule.tags.contains("permanent") || yamlRule.tags.contains("n_a"){
                            continue
                        }
                        if let result = compliance().checkCompliance(arguments: yamlRule.check, resultExpected: yamlRule.result) {
                            text = text + "\(yamlRule.id): \(result)\n"
                            
//                            os_log("What is %{public}@?", "threeve")
                        } else {
                            text = text + "no loggy"
                        }
                        
                        
                    }
                }
            }
            
        }
        
            try? text.write(to: fileURL, atomically: false, encoding: .utf8)
        
        
    }
    

    // get all the rules in the rules directory and sub directories
    func getDir() {
        ruleURLs.removeAll()
        
        if let folders = try? FileManager.default.contentsOfDirectory(at: URL.init(fileURLWithPath: defaultLocalRepoPath + "/rules"), includingPropertiesForKeys: [URLResourceKey.isDirectoryKey], options: .skipsHiddenFiles) {
            for folder in folders {
                let temprules = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [], options: .init())
                //            let inherent = defaultLocalRepoPath + "/rules/inherent/"
                let srg = defaultLocalRepoPath + "/rules/srg/"
                //            let not_applicable = defaultLocalRepoPath + "/rules/not_applicable/"
                let supplemental = defaultLocalRepoPath + "/rules/supplemental/"
                //            let permanent = defaultLocalRepoPath + "/rules/permanent/"
                if folder.absoluteString.contains(srg) || folder.absoluteString.contains(supplemental) {
                    continue
                } else {
                    ruleURLs.append(contentsOf: temprules!)
                }
            }
            
        }
        
    }
}

