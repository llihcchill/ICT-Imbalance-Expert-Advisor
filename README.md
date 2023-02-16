# ICT-Imbalance-Expert-Advisor

Overview:
---------
This is an MQL5 forex trading expert advisor that uses a unique pattern that gets entries early at the start of the two biggest trading sessions, 
the London session and the New York session. It only uses imbalances to gauge the sentiment before the former two trading periods on the 5
minute chart, and then goes down to the 1 minute chart to time a precise entry.

Strategy:
---------
For the London session trade, when the time reaches 8 A.M. GMT, it looks back the previous 12 bars (from the end of Asian session to start of London session) 
and attempts to find imbalances within that time. If there are more short imbalances, it makes a bias to place a long trade, and vice versa if there are more 
long imbalances. If there are no imbalances in that time period, it instead checks the close of the 12th candle and compares it to the 1st candle.
If the 12th candle is above the 1st candle, like the first part of the strategy, it makes a bias to go long and vice versa if it closes below.
After its bias is determined, it will then go down to the 1 minute timeframe and find another imbalance in the bias' direction and places a
limit order at the top of the imbalance. The New York session trade is the exact same as the initial strategy, except it starts when the time
reaches 1 P.M. GMT.
