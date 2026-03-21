import random
import string
import csv

def randomName():
    return random.choice([random.choice(string.ascii_letters) + random.choice(string.ascii_letters), random.choice(string.ascii_letters)])

def randomNumber():
    return str(random.randint(-100, 100))

def randomExpression(depth,parameters):
    if depth > 3:
        if parameters == []:
            return randomNumber()
        return random.choice([random.choice([row[0] for row in parameters if row]), randomNumber()])
    
    left = randomExpression(depth + 1,parameters)
    right = randomExpression(depth + 1,parameters)
    operator = random.choice(['+', '-', '*', '/'])
    
    return f'({left} {operator} {right})'

def randomExpressionNoNum(depth,parameters):
    if depth > 3:
        return random.choice([random.choice([row[0] for row in parameters if row])])
    
    left = randomExpressionNoNum(depth + 1,parameters)
    right = randomExpressionNoNum(depth + 1,parameters)
    operator = random.choice(['+', '-', '*', '/'])
    
    return f'({left} {operator} {right})'

def randomParam():
    p = [randomName(),randomNumber()]
    return p

def randomConstant(parameters):
    c = [randomName(),randomExpression(2,parameters)]
    return c

def randomFunctions(parameters,variable,state,control):
    text = ['','']
    for i in range(random.randint(1, 3)):
        name = randomName()
        if len(state) == 1:
            s = state[0]
        else:
            s = random.choice(state[1:])
        if parameters != []:
            expr = randomExpression(2,[random.choice([row[0] for row in parameters if row]),s])
        else:
            expr = randomExpression(2,[s])
        text[0] += f'{name}({s}) = {expr}, '
        text[1] += f'{name}({s}) = {expr}\n'
    return text

def randomState():
    n = random.randint(1, 3)
    if n != 1:
        s = ['s']
        for i in range(n):
            s.append(randomName())
    else:
        s = [randomName()]
    return s

def randomTime(variable):
    t = ['t']
    a = random.randint(0, 99)
    if 'ti' in variable:
        t.append('ti')
    else:
        t.append(random.choice([str(a),'0']))
    if 'tf' in variable:
        t.append('tf')
    else:
        t.append(str(random.randint(a+1, 100)))
    return t

def randomControl():
    n = random.randint(1, 3)
    if n != 1:
        s = ['u']
        for i in range(n):
            s.append(randomName())
    else:
        s = [randomName()]
    return s

def randomVariable():
    n = random.randint(1, 3)
    if n == 1:
        s = [random.choice([randomName()] + ['ti', 'tf'])]
    else:
        s = ['x']
        while len(s) < n+1:
            a = random.choice([randomName()] + ['ti', 'tf'])
            if a not in s:
                s.append(a)
    return s

def randomDynamics(parameters,variable,state,control):
    text = ['','']
    if len(state) == 1:
        start = 0
    else:
        start = 1
    for i in range(start,len(state)):
        left0 = '∂(' + state[i] + ')(t)'
        left1 = state[i] + '\'(t)'
        right = random.choice([randomExpression(2,parameters+variable+control),''])
        if right != '':
            text[0] += f'    {left0} == {right}\n'
            text[1] += f'    {left1} = {right}\n'
        
    return text

def randomInitialConditions(parameters,variable,state,control,time):
    text = ''
    if len(state) == 1:
        start = 0
    else:
        start = 1
    for i in range(start,len(state)):
        left = state[i] + '('+time[1]+')'
        if parameters == []:
            right = random.choice([randomNumber()] + [''])
        else:
            right = random.choice([random.choice(parameters)] + [randomNumber()] + [''])
        if right == '':
            text += f''
        else:
            text += f'    {left} == {right}\n'
    return text

def randomFinalConditions(parameters,variable,state,control,time):
    text = ''
    if len(state) == 1:
        start = 0
    else:
        start = 1
    for i in range(start,len(state)):
        left = state[i] + '('+time[2]+')'
        if parameters == []:
            right = random.choice([randomNumber()] + [''])
        else:
            right = random.choice([random.choice(parameters)] + [randomNumber()] + [''])
        if right == '':
            text += f''
        else:
            text += f'    {left} == {right}\n'
    return text

def randomStateConstraints(parameters,variable,state,control,time):
    text = ''
    if len(state) == 1:
        start = 0
    else:
        start = 1
    for i in range(start,len(state)):
        left = state[i] + '(t)'
        if parameters == []:
            right = random.choice([randomNumber()] + [''])
        else:
            right = random.choice([random.choice(parameters)] + [randomNumber()] + [''])
        if right == '':
            text += f''
        else:
            text += f'    {left} {random.choice(["≥", "≤"])} {right}\n'
    return text

def randomVariableConstraints(parameters,variable,state,control,time):
    text = ['','']
    if len(variable) == 1:
        start = 0
    else:
        start = 1
    for i in range(start,len(variable)):
        left = variable[i]
        if left == 'ti':
            if 'tf' in variable:
                right = 'tf'
                text[1] += f'    {left} ≤ {right}\n'
                continue
            else:
                right = time[2]
                text[1] += f'    {left} ≤ {right}\n'
                continue
        if left == 'tf':
            if 'ti' in variable:
                continue
            else:
                right = time[1]
                text[1] += f'    {left} ≥ {right}\n'
                continue
        if parameters == []:
            right = random.choice([randomNumber()] + [''])
        else:
            right = random.choice([random.choice(parameters)] + [randomNumber()] + [''])
        if right != '':
            text[0] += f'    {left} {random.choice(["≥", "≤"])} {right}\n'
            text[1] += f'    {left} {random.choice(["≥", "≤"])} {right}\n'
    return text

def randomControlConstraints(parameters,variable,state,control,time):
    text = ''
    if len(control) == 1:
        start = 0
    else:
        start = 1
    for i in range(start,len(control)):
        if parameters == []:
            left = random.choice([randomNumber()] + [''])
        else:
            left = random.choice([random.choice(parameters)] + [randomNumber()] + [''])
        middle = control[i] + '(t)'
        if parameters == []:
            right = random.choice([randomNumber()] + [''])
        else:
            right = random.choice([random.choice(parameters)] + [randomNumber()] + [''])
        if left == '':
            if right == '':
                text += f''
            else:
                text += f'    {middle} {random.choice(["≥", "≤"])} {right}\n'
        else:
            if right == '':
                text += f'    {middle} {random.choice(["≥", "≤"])} {left}\n'
            else:
                a = random.choice(["≥", "≤"])
                if left == right:
                    text += f'    {middle} {a} {left}\n'
                else:
                    text += f'    {left} {a} {middle} {a} {right}\n'
    return text

def randomObjective(parameters,variable,state,control,time):
    obj = random.choice(['min', 'max'])
    expr = random.choice([randomExpressionNoNum(3,variable+state+control),random.choice(variable+state+control)])
    if obj == 'min':
        textPrompt = f'minimize {expr}'
    else:
        textPrompt = f'maximize {expr}'
    return [textPrompt,f'    {expr} => {obj}']

def main():
    parameters = []
    variable = random.choice([randomVariable(),[]])
    state = randomState()
    control = randomControl()
    time = randomTime(variable)
    nbParam = random.choice([0, random.randint(1, 5)])
    for i in range(nbParam):
        parameters.append(randomParam())

    nbConst = random.choice([0, 0, random.randint(1, 3)])
    for i in range(nbConst):
        parameters.append(randomConstant(parameters))
    parametersName = []
    if parameters != []:
        parametersName = [row[0] for row in parameters if row]
    func = random.choice([['',''], ['',''], randomFunctions(parameters,variable,state,control)])

    dyn = randomDynamics(parametersName,variable,state,control)
    init = randomInitialConditions(parametersName,variable,state,control,time)
    final = randomFinalConditions(parametersName,variable,state,control,time)
    state_constr = randomStateConstraints(parametersName,variable,state,control,time)
    var_constr = randomVariableConstraints(parametersName,variable,state,control,time)
    control_constr = randomControlConstraints(parametersName,variable,state,control,time)
    objective = randomObjective(parametersName,variable,state,control,time)

    textPrompt = '###Prompt:\nTranslate the problem below into this DSL:\n\n'
    textPrompt += f'{objective[0]}\n'
    textPrompt += f'# Variable: {", ".join(variable) if variable else "None"}\n'
    textPrompt += f'# State: {", ".join(state) if state else "None"}\n'
    textPrompt += f'# Control: {", ".join(control) if control else "None"}\n'
    textPrompt += f'# Dynamics\n{dyn[1].strip()},\n# Initial Conditions\n{init.strip()},\n# Final Conditions\n{final.strip()},\n# State Constraints\n{state_constr.strip()},\n# Variable Constraints\n{var_constr[0].strip()},\n# Control Constraints\n{control_constr.strip()}\n'
    textPrompt = textPrompt.replace('≥', '=>').replace('≤', '<=').replace('==', '=').replace('    ', '').replace(', ,', ', ')
    if parameters != []:
        textPrompt += f'where {", ".join([f"{p[0]} = {p[1]}" for p in parameters])}'
    textPrompt += func[0]


    textDSL = '###DSL:\n'
    for i in parameters:
        textDSL += f'{i[0]} = {i[1]}\n'
    textDSL += func[1]
    textDSL += '\n@def begin\n'

    match len(variable):
        case 0:
            textDSL += ''
        case 1:
            textDSL += '    ' + variable[0] + ' ∈ R, variable\n'
        case 3:
            textDSL += '    ' + variable[0] + ' = (' + variable[1] + ', ' + variable[2] + ') ∈ R², variable\n'
        case 4:
            textDSL += '    ' + variable[0] + ' = (' + variable[1] + ', ' + variable[2] + ', ' + variable[3] + ') ∈ R³, variable\n'

    textDSL += '    ' + time[0] + ' ∈ [' + time[1] + ', ' + time[2] + '], time\n'
    
    match len(state):
        case 0:
            textDSL += ''
        case 1:
            textDSL += '    ' + state[0] + ' ∈ R, state\n'
        case 3:
            textDSL += '    ' + state[0] + ' = (' + state[1] + ', ' + state[2] + ') ∈ R², state\n'
        case 4:
            textDSL += '    ' + state[0] + ' = (' + state[1] + ', ' + state[2] + ', ' + state[3] + ') ∈ R³, state\n'
    
    match len(control):
        case 0:
            textDSL += '\n'
        case 1:
            textDSL += '    ' + control[0] + ' ∈ R, control\n\n'
        case 3:
            textDSL += '    ' + control[0] + ' = (' + control[1] + ', ' + control[2] + ') ∈ R², control\n\n'
        case 4:
            textDSL += '    ' + control[0] + ' = (' + control[1] + ', ' + control[2] + ', ' + control[3] + ') ∈ R³, control\n\n'
    
    textDSL += '    # Dynamics\n'
    textDSL += dyn[0] + '\n'
    textDSL += '    # Initial Conditions\n'
    textDSL += init + '\n'
    textDSL += '    # Final Conditions\n'
    textDSL += final + '\n'
    textDSL += '    # State Constraints\n'
    textDSL += state_constr + '\n'
    textDSL += '    # Variable Constraints\n'
    textDSL += var_constr[1] + '\n'
    textDSL += '    # Control Constraints\n'
    textDSL += control_constr + '\n'
    textDSL += '    # Objective\n'
    textDSL += objective[1] + '\n'
    textDSL += 'end\n<TOKEN_FINAL>'
    return [textPrompt,textDSL]

print(main())

with open('dataset.csv', 'w', newline='\n', encoding="utf-8") as csvfile:
    spamwriter = csv.writer(csvfile, delimiter=',',
                            quoting=csv.QUOTE_MINIMAL)
    spamwriter.writerow(['prompt', 'julia code'])
    for a in range(0,10000):

        spamwriter.writerow(main())
















