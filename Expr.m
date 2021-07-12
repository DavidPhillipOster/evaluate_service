//  Created by David Phillip Oster on 1/23/16.
//  Apache 2 License

#import "Expr.h"
#import <ctype.h>

typedef enum {
  kLexUninitialized,
  kLexPlus,
  kLexMinus,
  kLexTimes,
  kLexDivide,
  kLexInt,
  kLexHexInt,
  kLexFloat,
  kLexOpenParen,
  kLexCloseParen,
  kLexPrefix,
  kLexSuffix,
  kLexError,
  kLexEOF
} LexerToken;

// The lexical analyzer needs a representation of a lexical token that it can push and pop.
@interface Token : NSObject
@property(nonatomic) LexerToken verb;
@property(nonatomic) NSString *s; // non-null for prefix, suffix, number.

+ (instancetype)tokenWithVerb:(LexerToken)verb;

@end

@implementation Token

+ (instancetype)tokenWithVerb:(LexerToken)verb {
  Token *result = [[Token alloc] init];
  result.verb = verb;
  return result;
}

@end

#pragma mark -

// a Lexer is like an NSSscanner. It marches down the string it owns, returning successive Tokens.
// I could have used 'flex' but I wanted to keep this program small with minimal dependencies.
@interface Lexer : NSObject
- (instancetype)initWithString:(NSString *)string;
- (Token *)nextToken;
- (void)pushbackToken:(Token *)token;
@end

typedef enum NumberKind {
  NumberKindNot,
  NumberKindInt,
  NumberKindFloat,
  NumberKindHex,
} NumberKind;

@interface Lexer()
@property(nonatomic) Token *pushedToken;
@property(nonatomic) NSString *s;
@property(nonatomic) int i;
@property(nonatomic) int len;
@property(nonatomic) int numberStart;
@property(nonatomic) BOOL hasNextBeenCalled;
@end

@implementation Lexer

- (instancetype)initWithString:(NSString *)string {
  self = [super init];
  if (self) {
    _s = string;
    _len = (int)[_s length];
  }
  return self;
}


- (NumberKind)isAtStartOfNumber {
  if (_len <= _i) {
    return NumberKindNot;
  }
  unichar c = [_s characterAtIndex:_i];
  if (isdigit(c)) {
    _numberStart = _i;
    if (_len - 2 <= _i) {
      return NumberKindInt;
    }
    if ('0' == c && _i+2 < _len) {
      // we can look at the next two characters.
      unichar x1 = [_s characterAtIndex:_i+1];
      unichar x2 = [_s characterAtIndex:_i+2];
      if ('x' == x1 && ishexnumber(x2)) {
        _i += 2;
        return NumberKindHex;
      }
    }
    return NumberKindInt;
  }
  if (c == '.') {
    if (_len - 1 <= _i) {
      return NumberKindNot;
    }
    // we can look at the next character.
    unichar c1 = [_s characterAtIndex:_i+1];
    if (isdigit(c1)) {
      _numberStart = _i;
      _i++;
      return NumberKindFloat;
    }
  }
  return NumberKindNot;
}

- (void)pushbackToken:(Token *)token {
  NSAssert(nil == _pushedToken, @"");
  _pushedToken = token;
}

- (Token *)nextToken {
  if (_pushedToken) {
    Token *token = _pushedToken;
    _pushedToken = nil;
    return token;
  }
  if (_len <= _i) {
    return [Token tokenWithVerb:kLexEOF];
  }
  if (!_hasNextBeenCalled) {
    _hasNextBeenCalled = YES;
    // Assumes decimal separater s '.'.
    NSCharacterSet *startSet = [NSCharacterSet characterSetWithCharactersInString:@".-+(0123456789"];
    NSRange r = [_s rangeOfCharacterFromSet:startSet];
    if (r.location != 0) {
      NSRange r2 = NSMakeRange(0, r.location == NSNotFound ? _len : r.location);
      Token *result = [Token tokenWithVerb:kLexPrefix];
      result.s = [_s substringWithRange:r2];
      _i = (int)r2.length;
      return result;
    }
  }
  int startingI = _i;
  while (_i < _len) {
    NumberKind numberKind;
    LexerToken resultToken = kLexInt;
    unichar c = [_s characterAtIndex:_i];
    if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c]) {
      _i++;
    } else if (NumberKindNot != (numberKind = [self isAtStartOfNumber])) {
      if (NumberKindHex == numberKind) {
        while (_i < _len && '\0' != (c = [_s characterAtIndex:_i]) && ishexnumber(c)) {
          _i++;
        }
        resultToken = kLexHexInt;
      } else {
        BOOL hasSeenDecimalPoint = (numberKind == NumberKindFloat);
        while (_i < _len && '\0' != (c = [_s characterAtIndex:_i]) && isdigit(c)) {
          _i++;
        }
        if (_i < _len && '\0' != (c = [_s characterAtIndex:_i]) && '.' == c) {
          if (hasSeenDecimalPoint) {
            _i = _len;
            return [Token tokenWithVerb:kLexError];
          }
          resultToken = kLexFloat;
          _i++;
          while (_i < _len && '\0' != (c = [_s characterAtIndex:_i]) && isdigit(c)) {
            _i++;
          }
        }
      }
      NSRange r3 = NSMakeRange(_numberStart, _i - _numberStart);
      Token *result1 = [Token tokenWithVerb:resultToken];
      result1.s = [_s substringWithRange:r3];
      return result1;
    } else {
      switch (c) {
      case '*': _i++; return [Token tokenWithVerb:kLexTimes];
      case '/': _i++; return [Token tokenWithVerb:kLexDivide];
      case '+': _i++; return [Token tokenWithVerb:kLexPlus];
      case '-': _i++; return [Token tokenWithVerb:kLexMinus];
      case '(': _i++; return [Token tokenWithVerb:kLexOpenParen];
      case ')': _i++; return [Token tokenWithVerb:kLexCloseParen];
      default:
          _i = _len;
          break;
      }
    }
  } // end while
  if (_len <= _i && startingI < _i) {
    Token *result2 = [Token tokenWithVerb:kLexSuffix];
    result2.s = [_s substringWithRange:NSMakeRange(startingI, _len - startingI)];
    return result2;
  }
  return [Token tokenWithVerb:kLexError];
}

@end

#pragma mark -
// Takes a stream of tokens from the Lexer and builds a parse tree.
// I could have used 'bison' but I wanted all the algorithms here.
@interface Parser : NSObject
- (instancetype)initWithString:(NSString *)string;
- (double)topLevelExpression;
- (NSString *)evaluatedString;
@end

@interface Parser()
@property Lexer *lex;
@property NSString *prefixString;
@property NSString *suffixString;
@end

@implementation Parser

- (instancetype)initWithString:(NSString *)string {
  self = [super init];
  if (self) {
    _lex = [[Lexer alloc] initWithString:string];
  }
  return self;
}

- (double)terminal {
  Token *token = [_lex nextToken];
  if (kLexError == token.verb) {
    return NAN;
  } else if (kLexEOF == token.verb) {
    return NAN;
  } else if (kLexInt == token.verb) {
    NSScanner *scanint = [[NSScanner alloc] initWithString:token.s];
    int n;
    if ([scanint scanInt:&n]) {
      return n;
    }
  } else if (kLexHexInt == token.verb) {
    NSScanner *scanHex = [[NSScanner alloc] initWithString:token.s];
    unsigned n1;
    if ([scanHex scanHexInt:&n1]) {
      return n1;
    }
  } else if (kLexFloat == token.verb) {
    NSScanner *scanFloat = [[NSScanner alloc] initWithString:token.s];
    double n2;
    if ([scanFloat scanDouble:&n2]) {
      return n2;
    }
  } else if (kLexOpenParen == token.verb) {
    double opExpr = [self expression];
    if (isnan(opExpr)) {
      return opExpr;
    }
    token = [_lex nextToken];
    if (kLexCloseParen == token.verb) {
      return opExpr;
    }
  } else if (token.verb == kLexSuffix) {
    _suffixString = token.s;
    return NAN;
  }
  return NAN;
}

- (double)primary {
  Token *token = [_lex nextToken];
  if (token.verb == kLexMinus) {
    return -[self terminal];
  } else {
    [_lex pushbackToken:token];
    return [self terminal];
  }
}

- (double)factor {
  double result = [self primary];
  Token *token;
  for (token = [_lex nextToken];
      token.verb == kLexTimes || token.verb == kLexDivide;
      token = [_lex nextToken]) {
    if (token.verb == kLexTimes) {
      result *= [self primary];
    } else if (token.verb == kLexDivide) {
      result /= [self primary];
    }
  }
  [_lex pushbackToken:token];
  return result;
}

- (double)expression {
  double result = [self factor];
  Token *token;
  for (token = [_lex nextToken];
      token.verb == kLexPlus || token.verb == kLexMinus;
      token = [_lex nextToken]) {
    if (token.verb == kLexPlus) {
      result += [self factor];
    } else if (token.verb == kLexMinus) {
      result -= [self factor];
    }
  }
  [_lex pushbackToken:token];
  return result;
}

- (double)topLevelExpression {
  Token *token = [_lex nextToken];
  if (kLexPrefix == token.verb) {
    _prefixString = token.s;
  } else {
    [_lex pushbackToken:token];
  }
  double result = [self expression];
  token = [_lex nextToken];
  if (kLexSuffix == token.verb) {
    _suffixString = token.s;
  }
  return result;
}

- (NSString *)evaluatedString {
  double f = [self topLevelExpression];
  NSString *result = nil;
  if ( ! isnan(f)) {
    if (0.0 == f - floor(f)) {
      result = [NSString stringWithFormat:@"%@%ld%@", _prefixString ?: @"", (long)f, _suffixString ?: @""];
    } else {
      // a ?: b is a shorthand for a ? a : b
      result = [NSString stringWithFormat:@"%@%.6g%@", _prefixString ?: @"", f, _suffixString ?: @""];
    }
  }
  return result;
}

@end

#pragma mark -

@implementation Expression
+ (NSString *)evaluate:(NSString *)inS {
  Parser *parser = [[Parser alloc] initWithString:inS];
  return [parser evaluatedString];
}
@end

