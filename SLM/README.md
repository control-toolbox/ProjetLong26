
# SLM & Dataset Creator

## Overview
This project provides tools for working with Small Language Models (SLM) and creating custom datasets for OptimalControl.jl.

## Quick Start

### Using the SLM
1. Import your dataset and model if you run the notebook and colab (or create them since both code are in the project)
2. Write your math problem in cell 16 following this structure :  
###Prompt  
Translate the following problem into DSL:  

minimise tf  
\# Variable: tf  
\# State: s, q, v  
\# Control: u  
\# Dynamics  
q'(t) = v(t)  
v'(t) = u(t)  
\# Initial Conditions  
v(0) = -2  
q(0) = 1,  
\# Final Conditions  
q(tf) = 3  
v(tf) = 1,  
\# State Constraints  
v(t) <= 1,  
\# Variable Constraints  
,  
\# Control Constraints  
-1 <= u(t) <= 1  

3. run every cell (apart from the RAG part) if you want to create a new model or only cell 1, 2, 5, 16 to use the SLM
4. A file with the code should be downloaded (might not be compilable if the SLM makes a mistake)

### Dataset Creator
Run the python code and a .csv file should be created

## Configuration
python 3.12 should be enough
I recommend using GoogleColab to use the notebook


