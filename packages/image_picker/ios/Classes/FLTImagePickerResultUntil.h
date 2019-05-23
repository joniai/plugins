// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FLTImagePickerResultUntil : NSObject

+ (NSDictionary *)resultWithPath:(NSString *)path error:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
