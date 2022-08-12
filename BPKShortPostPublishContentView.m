//
//  BPKShortPostPublishContentView.m
//  BPKCommumityLib
//
//  Created by yiche on 2020/6/19.
//

#import "BPKShortPostPublishContentView.h"
#import "BPKForumPublishTopicController.h"
#import "BPKDynamicTopicModel.h"

@interface BPKShortPostPublishContentView ()<UITextViewDelegate>

@property (nonatomic, assign) CGFloat textViewHeight;

@property (nonatomic, assign) CGFloat minTextHeight;

// 设置最大可输入字符，2000
@property (nonatomic) NSInteger maxCharacter;
// 记录光标位置，处理中间插入话题
@property (nonatomic, assign) NSInteger insertLocation;

/// 是否允许创建话题，默认为NO（10.41）
@property (nonatomic, assign) BOOL createTopicEnable;

@end

#define BPKPostPublishShortPlaceHolder @"欢迎写一些车相关的真实感受！图片精美、有看点的内容更容易获得推荐（最多发布9张图片）\n安全指南：请勿发布带有个人信息（如：车牌号）图片"
#define BPKEnergyConsumptionPlaceHolder @"拍照晒一晒你的仪表盘，根据你的驾驶习惯和用车环境聊聊对爱车能耗的感想。"

@implementation BPKShortPostPublishContentView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor whiteColor];
        self.maxCharacter = 2000;
        self.minTextHeight = 180.f;
        self.textViewHeight = self.minTextHeight + 26;
        [self layoutUI];
        [self requestUserRoles];
    }
    return self;
}

- (void)layoutUI {
    [self addSubview:self.textView];
    [self.textView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self).offset(kBPKForumMarginX);
        make.left.equalTo(self).offset(20);
        make.right.equalTo(self).offset(-20);
        make.height.greaterThanOrEqualTo(@(self.minTextHeight));
    }];
}

- (void)setPublishModel:(BPKPostPublishModel *)publishModel {
    _publishModel = publishModel;
    self.textView.text = publishModel.shortContent;
    [self textViewDidChange:self.textView];
}
- (void)setPublishType:(NSInteger)publishType {
    _publishType = publishType;
    if (publishType == 1) {
        self.textView.placeholder = BPKEnergyConsumptionPlaceHolder;
    } else {
        self.textView.placeholder = BPKPostPublishShortPlaceHolder;
    }
}

/// 选择话题
- (void)selectLinkTopic {
    BOOL isEditing = NO;
    // 正在编辑，编辑的是正文
    if (self.textView) {
        isEditing = [self.textView isFirstResponder];
        [self.textView resignFirstResponder];
    }
    [self selectLinkTopicIsEditing:isEditing isInput:NO];
//    [self selectLinkTopicWithInput:NO];
}

/// isEditing:是否是正文编辑时插入话题，NO，需要将话题插入到第一段
/// input：正文编辑时插入话题，话题来源是否是输入#
- (void)selectLinkTopicIsEditing:(BOOL)isEditing isInput:(BOOL)input  {
    if (self.viewShow == YES) return;
    self.viewShow = YES;
    // 记录光标位置
    [self recordLocation];
    [self.textView resignFirstResponder];
    BPKForumPublishTopicController *selectTopicVC = [[BPKForumPublishTopicController alloc] init];
    selectTopicVC.createTopicEnable = self.createTopicEnable;
    @weakify(self)
    // 插入话题
    selectTopicVC.topicSelectBlock = ^(BPKDynamicTopicModel * _Nonnull topicModel) {
        @strongify(self)
//        [self topicSelectedWithTopicModel:topicModel withInput:input];
        if (isEditing) { // 插入到正文
            [self topicSelectedWithTopicModel:topicModel withInput:input];
        } else {
            // 非编辑状态时点击底部按钮，话题插入到第一段正文最前面
            [self insertLinkTopic:topicModel input:input];
        }
    };
    BPTBaseNavigationController *nav = [[BPTBaseNavigationController alloc] initWithRootViewController:selectTopicVC];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [[BPTViewTools topViewController] presentViewController:nav animated:YES completion:nil];
}

- (void)topicSelectedWithTopicModel:(BPKDynamicTopicModel *)topicModel withInput:(BOOL)input {
    if (![self.textView isFirstResponder]) {
        [self.textView becomeFirstResponder];
    }
    [self insertLinkTopic:topicModel input:input];
}

/// 插入关联话题
- (void)insertLinkTopic:(BPKDynamicTopicModel *)topicModel input:(BOOL)input {
    /// 未选择
    if (topicModel == nil) {
        if (input) { // 输入#调起选择列表，需要手动拼接#
            NSString *string = [NSString stringWithFormat:@"%@#",BPKEnsureString(self.publishModel.shortContent)];
            self.publishModel.shortContent = string;
            self.textView.text = self.publishModel.shortContent;
            [self textViewDidChange:self.textView];
        }
        return;
    }
    NSMutableString *string = [[NSMutableString alloc] initWithString:BPKEnsureString(self.publishModel.shortContent)];
    NSString *topicShowName = [NSString stringWithFormat:@"#%@#",topicModel.topicName];
    [self.publishModel.topicKeyValues setObject:topicModel forKey:topicShowName];
    /// 防止误操作删除#，添加一个空格
    NSString *inserName = [NSString stringWithFormat:@"%@ ",topicShowName];
    if (self.insertLocation >= 0 && self.insertLocation < self.publishModel.shortContent.length) { // 中间插入
        [string insertString:inserName atIndex:self.insertLocation];
    } else { // 最后
        [string appendString:inserName];
    }
    self.publishModel.shortContent = string;
    self.textView.text = self.publishModel.shortContent;
    [self textViewDidChange:self.textView];
}


// 记录光标位置
- (void)recordLocation {
    if (self.textView.selectedRange.location != NSNotFound) {
        self.insertLocation = self.textView.selectedRange.location;
    } else {
        self.insertLocation = -1;
    }
}

/// 请求用户权限，判断是否可以创建话题
- (void)requestUserRoles {
    @weakify(self)
    [BPKDataHelper getUserForumRoles:@"-1" completion:^(BPEResponseModel *model) {
        @strongify(self)
        // 不显示权限管理
        BOOL showRole = NO;
        if(model.statusCode == BPEStatusSuccessCode &&
        IsDictionaryWithAnyKeyValue(model.responseData)) {
            NSDictionary *roleDic = [model.responseData objectForKey:@"role"];
            NSInteger roleId = [roleDic BPT_integerForKey:@"roleId"];
            // 超管和编辑的创建权限
            if (roleId == 4 || roleId == 5) {
                self.createTopicEnable = YES;
            }
        }
    }];
}



#pragma mark - UITextViewDelegate

/// 获取光标位置
- (void)textViewDidChangeSelection:(UITextView *)textView {
    [BPKFormatHelper topicTextViewDidChangeSelection:textView withTopicRanges:self.publishModel.topicRanges];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"#"]) {
//        [self selectLinkTopicWithInput:YES];
        [self selectLinkTopicIsEditing:YES isInput:YES];
        return NO;
    }
    if ([text isEqualToString:@""]) { // 删除
        return [BPKFormatHelper topicTextViewDidDelete:textView inRange:range withTopicRanges:self.publishModel.topicRanges topicKeyValues:self.publishModel.topicKeyValues];
    }
    return YES;
}


- (void)textViewDidChange:(UITextView *)textView {
    UITextRange *textRange = textView.markedTextRange;
    // 没有高亮选择的字，则对已输入的文字进行字数统计和限制
    if (!textRange) {
        if (textView.text.length > self.maxCharacter) {
            NSString *text = BPKEnsureString(textView.text);
            textView.text = [text ycb_substringToIndex:self.maxCharacter];
        }
        self.publishModel.shortContent = textView.text;
        if (self.textDidChangeBlock) {
            self.textDidChangeBlock();
        }
        // 记录光标位置
        NSRange selectedRange = textView.selectedRange;
        if (selectedRange.location == NSNotFound) {
            selectedRange.location = textView.text.length;
        }
        UIFont *font = BPKTextViewFont;
        [BPKFormatHelper getNewTopicDataForPublishFromContent:self.publishModel.shortContent topicKeyValues:self.publishModel.topicKeyValues font:font complete:^(NSAttributedString * _Nonnull topicAttributed, NSString * _Nonnull linkContent, NSArray * _Nonnull topicRanges, NSArray * _Nullable topicIds) {
            self.publishModel.shortLinkContent = linkContent;
            [self.publishModel.topicRanges removeAllObjects];
            self.publishModel.topicIds = topicIds;
            if (IsArrayWithAnyItem(topicRanges)) {
                [self.publishModel.topicRanges addObjectsFromArray:topicRanges];
            }
            if (topicAttributed) {
                textView.attributedText = topicAttributed;
            } else {
                textView.text = self.publishModel.shortContent;
            }
        }];
        textView.selectedRange = selectedRange;
        CGFloat textHeight = [textView.text boundingRectWithSize:CGSizeMake(BPT_MAINWIDTH_MIN - 40, MAXFLOAT) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:font} context:nil].size.height + 1;
        if (textHeight < self.minTextHeight) {
            textHeight = self.minTextHeight;
        }
        if (self.textViewHeight != textHeight) {
            self.textViewHeight = textHeight;
            self.BPT_height = textHeight + 10 + kBPKForumMarginX;
            if (self.updateHeightBlock) {
                self.updateHeightBlock(textHeight + 10 + kBPKForumMarginX);
            }
        }
    }
}

- (BPKTextView *)textView {
    if (!_textView) {
        _textView = [[BPKTextView alloc] init];
        _textView.scrollEnabled = NO;
        _textView.backgroundColor = [UIColor BPT_colorWithHexString:@"#FFFFFF"];
        _textView.delegate = self;
        _textView.font = BPKTextViewFont;
        _textView.textColor = [UIColor BPT_colorWithHexString:@"#222222"];
        _textView.placeholder = BPKPostPublishShortPlaceHolder;
    }
    return _textView;
}


@end
