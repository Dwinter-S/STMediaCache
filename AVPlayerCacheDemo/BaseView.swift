//
//  BaseView.swift
//  study-abroad
//
//  Created by huangpeidong on 2020/4/28.
//  Copyright © 2020 HCP. All rights reserved.
//

import UIKit
import RxSwift

class BaseView: UIView {
    
    let disposeBag = DisposeBag()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupBindView()
        setupBindViewModel()
        setuped()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUI()
        setupConstraints()
        setupBindViewModel()
        setuped()
    }
    
    func setupUI() {
      
    }
    
    func setupConstraints() {
       
    }
    
    func setupBindView() {
        
    }
    
    func setupBindViewModel() {
        
    }
    
    func setuped() {
         
    }
}
