expr = "178 + 2 * (3 - -1) / 290"

i = 0
tokens = []
current = ""
while i < len(expr):
    c = expr[i]
    if c == ' ':
        tokens.append(current)
        current = ''
    elif c == '(':
        tokens.append(current)
        tokens.append('(')
        current = ''
    elif c == ')':
        tokens.append(current)
        tokens.append('(')
        current = ''        
    else:
        current += c
    i +=1

tokens.append(current)

print tokens
