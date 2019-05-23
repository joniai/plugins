// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FLTImagePickerResultUntil.h"

@implementation FLTImagePickerResultUntil

+ (NSDictionary *)resultWithPath:(NSString *)path error:(NSError *)error {
  return @{
           @"path":path?:[NSNull null],
           @"errorCode":@(error.code),
           @"errorDomain":error.domain?:@"",
           @"errorUserInfo":error.userInfo
           };
}

@end
