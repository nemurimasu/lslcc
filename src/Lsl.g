grammar Lsl;

options {
	backtrack=true;
	memoize=true;
	output=AST;
}
tokens {
	SCRIPT;
	VARIABLE;
	FUNCTION;
	STATES;
	STATE;
	VALUE;
	GLOBALS;
	PARAMS;
	EVENTS;
	PARAM;
	TYPE;
	NAME;
	BODY;
	VOID;
	STATE_CHANGE;
	JUMP;
	RETURN;
	LABEL;
	IF;
	ELSE;
	CONDITION;
	CALL;
	CAST;
	FOR;
	PRECOMMANDS;
	LOOPCOMMANDS;
	EXPRESSION;
	WHILE;
	LIST;
	DO;
	VECTOR;
	QUATERNION;
}
@header {
package org.lslcc.antlr;
}
@lexer::header {
package org.lslcc.antlr;
}

@lexer::members {
  @Override
  public void reportError(RecognitionException e) {
    super.reportError(e);
    throw new Error(e);
  }
}

INTEGER_TYPE : 'integer' ;
FLOAT_TYPE : 'float' ;
STRING_TYPE : 'string' ;
LLKEY_TYPE : 'key' ;
VECTOR_TYPE : 'vector' ;
QUATERNION_TYPE : 'rotation' ;
LIST_TYPE : 'list' ;

STATE_KEY : 'state' ;
JUMP_KEY : 'jump' ;
RETURN_KEY : 'return' ;
IF_KEY : 'if' ;
ELSE_KEY : 'else' ;
FOR_KEY : 'for' ;
DO_KEY : 'do' ;
WHILE_KEY : 'while' ;

ADD_ASSIGN : '+=' ;
SUB_ASSIGN : '-=' ;
MUL_ASSIGN : '*=' ;
DIV_ASSIGN : '/=' ;
MOD_ASSIGN : '%=' ;
EQ : '==' ;
NEQ : '!=' ;
LEQ : '<=' ;
GEQ : '>=' ;
BOOLEAN_AND : '&&' ;
BOOLEAN_OR : '||' ;
SHIFT_LEFT : '<<' ;
SHIFT_RIGHT : '>>' ;
INC_OP : '++' ;
DEC_OP : '--' ;

DEFAULT_KEY : 'default' ;

IDENTIFIER  :	('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'0'..'9'|'_')*
    ;

INT :	'0'..'9'+ | '0' ('x' | 'X') HEX_DIGIT+
    ;

FLOAT
    :   ('0'..'9')+ '.' ('0'..'9')* EXPONENT?
    |   '.' ('0'..'9')+ EXPONENT?
    |   ('0'..'9')+ EXPONENT
    |   ('0'..'9')+ ('f' | 'F')
    ;

COMMENT
    :   '//' (~('\n')* ~('\n'|'\r'))? '\r'? '\n' {$channel=HIDDEN;}
    |   '/*' ( options {greedy=false;} : . )* '*/' {$channel=HIDDEN;}
    ;

WS  :   ( ' '
        | '\t'
        | '\r'
        | '\n'
        | '\ufeff'
        ) {$channel=HIDDEN;}
    ;

STRING
    :  '"' ( ('\\' .) | ~('"' | '\\') )* '"'
    ;

fragment
EXPONENT : ('e'|'E') ('+'|'-')? ('0'..'9')+ ;

fragment
HEX_DIGIT : ('0'..'9'|'a'..'f'|'A'..'F') ;

lscriptProgram : global* states -> ^(SCRIPT ^(GLOBALS global*) states) ;
global : globalVariable | globalFunction ;
nameType : typename IDENTIFIER -> ^(TYPE typename) ^(NAME IDENTIFIER) ;
globalVariable : nameType ';' -> ^(VARIABLE nameType)
	| nameType '=' simpleAssignable ';' -> ^(VARIABLE nameType ^(VALUE simpleAssignable));
simpleAssignable : simpleAssignableNoList | listConstant ;
simpleAssignableNoList : IDENTIFIER | constant | specialConstant ;
constant : integerConstant | fpConstant | STRING ;
fpConstant : FLOAT | '-' FLOAT ;
integerConstant : INT | '-' INT ;
specialConstant : '<' simpleAssignable ',' simpleAssignable ',' simpleAssignable '>' -> ^(VECTOR ^(VALUE simpleAssignable) ^(VALUE simpleAssignable) ^(VALUE simpleAssignable))
	| '<' simpleAssignable ',' simpleAssignable ',' simpleAssignable ',' simpleAssignable '>' -> ^(QUATERNION ^(VALUE simpleAssignable) ^(VALUE simpleAssignable) ^(VALUE simpleAssignable) ^(VALUE simpleAssignable)) ;
listConstant : '[' listEntry? ']' -> ^(LIST listEntry?);
listEntry : listEntryW (',' listEntryW)* -> listEntryW+ ;
listEntryW : simpleAssignableNoList -> ^(VALUE simpleAssignableNoList) ;
typename : INTEGER_TYPE | FLOAT_TYPE | STRING_TYPE | LLKEY_TYPE | VECTOR_TYPE | QUATERNION_TYPE | LIST_TYPE ;
globalFunction : optionalType IDENTIFIER '(' functionParameters? ')' compoundStatement -> ^(FUNCTION ^(TYPE optionalType) ^(NAME IDENTIFIER) ^(PARAMS functionParameters?) compoundStatement) ;
optionalType : typename | -> VOID ;
functionParameters : functionParameter (',' functionParameter)* -> functionParameter+ ;
functionParameter : nameType -> ^(PARAM nameType) ;
states : defaultState state* -> ^(STATES defaultState state*) ;
defaultState : DEFAULT_KEY '{' stateBody '}' -> ^(STATE ^(NAME DEFAULT_KEY) ^(EVENTS stateBody)) ;
state : STATE_KEY IDENTIFIER '{' stateBody '}' -> ^(STATE ^(NAME IDENTIFIER) ^(EVENTS stateBody)) ;
stateBody : event* ;
event : IDENTIFIER '(' functionParameters? ')' compoundStatement -> ^(FUNCTION ^(TYPE VOID) ^(NAME IDENTIFIER) ^(PARAMS functionParameters?) compoundStatement) ;
compoundStatement : '{' statement* '}' -> ^(BODY statement*) ;
statement : ';'
	| STATE_KEY IDENTIFIER ';' -> ^(STATE_CHANGE IDENTIFIER)
	| JUMP_KEY IDENTIFIER ';' -> ^(JUMP IDENTIFIER)
	| '@' IDENTIFIER ';' -> ^(LABEL IDENTIFIER)
	| RETURN_KEY expexpression? ';' -> ^(RETURN expexpression?)
	| expression ';' -> ^(EXPRESSION expression)
	| declaration ';' -> declaration
	| compoundStatement
	| IF_KEY '(' expression ')' statement (ELSE_KEY statement)? -> ^(IF ^(CONDITION expression) ^(BODY statement) ^(ELSE ^(BODY statement?)))
	| FOR_KEY '(' forexpressionlista? ';' expression ';' forexpressionlistb? ')' statement -> ^(FOR ^(PRECOMMANDS forexpressionlista?) ^(CONDITION expression) ^(LOOPCOMMANDS forexpressionlistb?) ^(BODY statement))
	| DO_KEY statement WHILE_KEY '(' expression ')' ';' -> ^(DO ^(BODY statement) ^(CONDITION expression))
	| WHILE_KEY '(' expression ')' statement -> ^(WHILE ^(CONDITION expression) ^(BODY statement)) ;
declaration : nameType -> ^(VARIABLE nameType)
	| nameType '=' expression -> ^(VARIABLE nameType ^(VALUE expression));
forexpressionlista : forexpressionlist ;
forexpressionlistb : forexpressionlist ;
forexpressionlist : expexpression (',' expexpression)* -> expexpression+;
funcexpressionlist : paramexpression (',' paramexpression)* -> paramexpression+;
listexpressionlist : valexpression (',' valexpression)* -> valexpression+;
paramexpression : expression -> ^(VALUE expression) ;
expexpression : expression -> ^(EXPRESSION expression) ;
valexpression : expression -> ^(VALUE expression) ;
operator : EQ | NEQ | LEQ | GEQ | '<' | '>' | '+' | '-' | '*' | '/' | '%' | '&' | '|' | '^' | BOOLEAN_AND | BOOLEAN_OR | SHIFT_LEFT | SHIFT_RIGHT;
assignment : ('=' | ADD_ASSIGN | SUB_ASSIGN | MUL_ASSIGN | DIV_ASSIGN | MOD_ASSIGN);
expression : (unaryexpression | lvalue assignment expression) (operator expression)*;
unaryop : '-' | '!' | '~' ;
unaryexpression : unaryop expression
	| (INC_OP | DEC_OP) lvalue
	| typecast
	| unarypostfixexpression
	| '(' expression ')' -> ^(EXPRESSION expression) ;
	typecast : '(' typename ')' expression -> ^(CAST ^(TYPE typename) ^(VALUE expression)) ;
unarypostfixexpression : specialInitializer | listInitializer | lvalue (INC_OP | DEC_OP)? | IDENTIFIER '(' funcexpressionlist? ')' -> ^(CALL ^(NAME IDENTIFIER) ^(PARAMS funcexpressionlist?)) | constant ;
specialInitializer : '<' valexpression ',' valexpression ',' valexpression '>' -> ^(VECTOR valexpression valexpression valexpression)
	| '<' valexpression ',' valexpression ',' valexpression ',' valexpression '>' -> ^(QUATERNION valexpression valexpression valexpression valexpression) ;
listInitializer : '[' listexpressionlist? ']' -> ^(LIST listexpressionlist?) ;
lvalue : IDENTIFIER ('.' IDENTIFIER)? ;
