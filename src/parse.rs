use crate::ast::{self, Expr, ExprKind, UnOp};
use crate::lexer::{self, Lexer, Token, TokenKind};

pub struct Parser {
    lexer: Lexer,
}

impl Parser {
    pub fn new(lexer: Lexer) -> Self {
        Parser { lexer }
    }

    fn peek_token(&mut self) -> Option<&Token> {
        self.lexer.peek_token()
    }

    fn skip_token(&mut self) -> Option<Token> {
        self.lexer.skip_token()
    }

    /// Skip token only when bumping into the expected token.
    fn skip_expected_token(&mut self, kind: TokenKind) -> bool {
        match self.lexer.peek_token() {
            Some(t) if t.kind == kind => {
                self.lexer.skip_token();
                true
            }
            _ => false,
        }
    }

    fn at_eof(&mut self) -> bool {
        matches!(
            self.peek_token(),
            Some(&Token {
                kind: TokenKind::Eof,
                ..
            })
        )
    }

    pub fn parse_crate(&mut self) -> Option<Expr> {
        let expr = self.parse_expr();
        if !self.at_eof() {
            return None;
        }
        expr
    }

    fn parse_expr(&mut self) -> Option<Expr> {
        let Some(t) = self.lexer.peek_token() else {
            return None;
        };

        match t.kind {
            TokenKind::NumLit(_)
            | TokenKind::OpenParen
            | TokenKind::BinOp(lexer::BinOp::Plus | lexer::BinOp::Minus) => self.parse_binary(),
            _ => {
                eprintln!("Expected expr, but found {:?}", t);
                None
            }
        }
    }

    // binary ::= add
    fn parse_binary(&mut self) -> Option<Expr> {
        self.parse_binary_add()
    }

    // add ::= mul ("+"|"-") add
    fn parse_binary_add(&mut self) -> Option<Expr> {
        let Some(lhs) = self.parse_binary_mul() else {
            return None;
        };

        let Some(t) = self.lexer.peek_token() else {
            return None;
        };
        let binop = match t.kind {
            TokenKind::BinOp(lexer::BinOp::Plus) => ast::BinOp::Add,
            TokenKind::BinOp(lexer::BinOp::Minus) => ast::BinOp::Sub,
            _ => {
                return Some(lhs);
            }
        };
        self.lexer.skip_token();

        let Some(rhs) = self.parse_binary_add() else {
            return None;
        };

        Some(Expr {
            kind: ExprKind::Binary(binop, Box::new(lhs), Box::new(rhs)),
        })
    }

    // mul ::= unary "*" mul
    fn parse_binary_mul(&mut self) -> Option<Expr> {
        let Some(lhs) = self.parse_binary_unary() else {
            return None;
        };

        let Some(t) = self.lexer.peek_token() else {
            return None;
        };
        let binop = match t.kind {
            TokenKind::BinOp(lexer::BinOp::Star) => ast::BinOp::Mul,
            _ => {
                return Some(lhs);
            }
        };
        self.lexer.skip_token();

        let Some(rhs) = self.parse_binary_mul() else {
            return None;
        };

        Some(Expr {
            kind: ExprKind::Binary(binop, Box::new(lhs), Box::new(rhs)),
        })
    }

    // unary ::= ("+"|"-") primary
    fn parse_binary_unary(&mut self) -> Option<Expr> {
        let Some(t) = self.lexer.peek_token() else {
            return None;
        };

        let unup = match &t.kind {
            TokenKind::BinOp(lexer::BinOp::Plus) => UnOp::Plus,
            TokenKind::BinOp(lexer::BinOp::Minus) => UnOp::Minus,
            _ => {
                return self.parse_binary_primary();
            }
        };
        // skip unary op token
        self.skip_token();

        let Some(primary) = self.parse_binary_primary() else {
            return None;
        };
        Some(Expr {
            kind: ExprKind::Unary(unup, Box::new(primary)),
        })
    }

    // primary ::= num | "(" expr ")"
    fn parse_binary_primary(&mut self) -> Option<Expr> {
        let Some(t) = self.lexer.skip_token() else {
            return None;
        };
        match t.kind {
            TokenKind::NumLit(n) => Some(Expr {
                kind: ExprKind::NumLit(n),
            }),
            TokenKind::OpenParen => {
                let Some(expr) = self.parse_expr() else {
                    return None;
                };
                if !self.skip_expected_token(TokenKind::CloseParen) {
                    eprintln!("Expected ')', but found {:?}", self.peek_token());
                    return None;
                }
                Some(expr)
            }
            _ => {
                eprintln!("Expected num or (expr), but found {:?}", t);
                None
            }
        }
    }
}
