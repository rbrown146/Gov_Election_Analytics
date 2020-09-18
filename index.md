## Predicting the 2020 Election (Rick Brown)

### Week of 9/13: It's The Economy, Stupid

It has long been said that the economy decides elections. Political scientists have argued that [there is a noticeable correlation](https://hollis.harvard.edu/primo-explore/fulldisplay?docid=TN_cdi_askewsholts_vlebooks_9781400888740&context=PC&vid=HVD2&search_scope=everything&tab=everything&lang=en_US) between an incumbent party's vote share and economic measures like GDP, RDI, and the inflation rate. Is this truly the case? In this blog post I use presidential election data since 1948 to show that while there is some correlation between RDI/GDP and an incumbent party's vote share, other measures like the inflation rate, unemployment rate, and stock market performance are much weaker measures.

#### GDP and RDI

Plotting scatterplots between incumbent party voteshare (popular two party vote, or PV2P) and GDP and RDI respectively shows that a positive, moderately strong correlation exists:

![](./Images/GDP.png) 

![](./Images/RDI.png)

The graphs suggest that GDP is a slightly better predictor than RDI. But numerically, just how good are these measures at predicting vote share? Examining the coefficients for the line of best fit for each graph, we can see that GDP has a statistically significant t value (less than 1.96) while RDI does not. In simpler terms, that means that the correlation between GDP and two party voteshare is highly unlikely to be random while the correlation between RDI and two party voteshare might be due to chance given the data we have:

GDP

![](./Images/coeffs_gdp.png)

RDI

![](./Images/coeffs_rdi.png)

Leaving out data for the 2016 election, we can test the accuracy of the models for GDP and RDI respectively by predicting what share of the popular vote Clinton should earn as compared to what she actually earned. Our predictions are the following:

Actual Clinton Voteshare - 51.16%
GDP Model Clinton Voteshare - 50.31%
RDI Model Clinton Voteshare - 47.97%

Here, too, it seems like GDP is a better predictor than RDI. But what do the two models predict Trump's voteshare will be in 2020?

GDP Model Trump Voteshare 2020 - 21.26%
RDI Model Trump Voteshare 2020 - 80.33%

Neither of these predictions seems realistic. All of the polls seem to show Trump neck-in-neck with Biden. So why are the models off by so much? GDP declined tremendously in the second quarter of 2020 due to COVID shutdowns while RDI increased as a result of stimulus checks and increased unemployment benefits. Since both were temporary changes caused by a pandemic, I doubt that either prediction will come close to accurately describing this year's election.

#### Inflation and Unemployment

### Week of 9/6: Past Insights

Analyzing swing states has long been a hallmark American election forecasts, and 2020 looks to be no different. This time there is much buzz about a wider field of states being in play than ever before: staples like Iowa, Ohio, Florida, and New Hampshire are frequently mentioned, but this time so are more unusual choices like Arizona, Georgia, Michigan, Pennsylvania, Wisconsin, and Texas. Perhaps this is because of the chaos caused by the coronavirus epidemic, or perhaps due to the drama of the Trump administration. Regardless of why, are this many states actually in play for Joe Biden, and if so, is this as unusual as it's made out to be?

Well, let's first look at a summary of each party's statewide margin of victory for presidential elections since 1980:

![](./Images/PV_margin_grid_1980.png)

Even since 1980 candidates seem to be running closer races in most states; with the exception of Utah, Idaho, and Wyoming, most states seem to very widely in intensity from strongly Republican to more moderately so (or perhaps even Democratic). This trend away from Republicanism bodes well for Biden. But given the many changes that have happened since 1980, like the downfall of the USSR and creation of Google, more relevant insights for the 2020 election will likely come from the past two decades.

![](./Images/PV_margin_2004.png)

In this shorter timespan it still seems evident that many states are not solidly Republican or Democratic. Democratic strongholds in the Northeast and Rust Belt region appear to be increasingly less Democratic while Republican strength in the Southeast is diminishing. (There are exceptions, of course - New York, Kentucky, and West Virginia vote increasingly for a particular party within this time frame.) The Southwest and Texas look very much in flux.

Graphing the change in party vote share in each state since the previous election should give us greater insight into the exact political trends by region:

![](./Images/PV_partisan_1980.png)

The country seems to have become more Democratic after the presidencies of Ronald Reagan and George W. Bush and more Republican during the presidency of Barack Obama. The pendulum metaphor of American politics seems to hold, although lately it has weakened:

![](./Images/PV_partisan_2004.png)

The country has trended more Republican in the past few elections with the exceptions of Arizona, California, Texas, and Georgia. Besides California all of these states have been considered swing states this election by at least some notable pundits. Assuming that these states are becoming Democratic faster than traditionally Democratic states are becoming Republican (which looks true), this should benefit Biden. Iowa seems to be going in the opposite direction, however, so it seems a stretch to call it a swing state this cycle. Overall it looks like, at best, presidents can only weakly grow their support when running for reelection, and in many states they lose voteshare. This will not benefit Donald Trump.

Just how many states have been competitive the past few cycles? The map below looks at states in which the two party voteshare for president was 5 points or less; it then colors states based on how much the voteshare changed from the previous election.

![](./Images/large_swing.png)

The trend seems to be going downward: from a peak of 12 in 2000 to a low of four in 2012, although the number since increased this past election. As America becomes more polarized the number of competitive states diminishes. This being the case, it does seem highly unusual that there are as many toss-up states this cycle as forecasted. But as for the states that are considered competitive, is this truly the case? As the map above indicates, lately it is highly unusual for states to swing by more than 2 points during a president's reelection bid (compare the number of purple states in 2004 and 2012 to the other years). If this trend holds true for this election then most of the states we consider swing states should have been carried in 2016 with a margin of victory of no more than 2% since states with a voteshare gap greater than 2% are highly unlikely to flip for another candidate.

![](./Images/2016_close.png)

As the map above indicates, many states considered swing states by pundits were in fact carried by this margin. However, North Carolina, Georgia, Arizona, Ohio, Texas and Iowa do not fit into this category. Voting trends discussed previously seem to suggest that Arizona is in fact competitive, but it seems like a stretch to label the remainder as swing states absent a large deviation from past voting patterns.
