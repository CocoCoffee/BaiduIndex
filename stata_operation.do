import delimited "/Users/hefan/PycharmProjects/Headache/data.csv",clear
timer clear

encode city, gen(city_)
// drop if keyword!="偏头痛"
xtset city_ day

gen big_city=1
replace big_city=0 if (city=="石家庄") | (city=="保定") | (city=="太原") | (city=="徐州") | (city=="中山")

// misstable summarize
// tsreport

gen month_mod = mod(month,12) + 1
tabulate month_mod, generate(month_)

global X "airtemp pressure windspeed dewpoint humidity feelingtemp aqi co no2 o3 pm10 pm25 so2"
global X1 "airtemp windspeed humidity co no2 o3 pm25 so2"
global X_final "airtemp windspeed humidity no2 o3"
global cv "pc_mobile airtemp pressure windspeed humidity co no2 o3 pm25 so2"
global Y "pc_mobile"

foreach var of varlist pressure co no2 o3 pm10 pm25 so2 aqi pc_mobile {
	replace `var'=log(`var'+1)
}


// desc
outreg2 using desc.doc,replace sum(log) title(Descriptive statistics) 

// pwcorr
// logout, save(xxx) word replace: pwcorr $Y $X 
asdoc pwcorr $Y $X1 , star(all) nonum


// global X airtemp humidity pm25 no2

// ------------- 单位根检验 ----------------
sort city_ day
//unbalanced dataset , p-value <0.05 均拒绝原假设，认为数据平稳，不需要差分处理！
foreach var in $X $Y {
	xtunitroot fisher `var', dfuller lags(1)
}

// 明确指定工具变量，可以更好地处理内生性问题，提高估计结果的稳健性和效率
// 据此选择合适的lag, instl > maxlag !
// 使用varsoc，减少时间消耗


global X "airtemp windspeed humidity co no2 o3 so2 pm25"
* pm25 
// global X "airtemp pressure windspeed humidity feelingtemp aqi co no2 o3 pm10 so2"

global d_X ""
global d_Y d_$Y
foreach var of varlist $X {
	capture gen d_`var'=D.`var'
	global d_X "$d_X d_`var'"
}
capture gen d_$Y = D.$Y

//varsoc $Y $X if city_==1, maxlag(10) exog(month_1-month_12) 
varsoc $d_Y $d_X if city_==1 & day<200,maxlag(20)
varsoc $Y $X if city_==1,maxlag(10)
//pvaropts(instlags(1/11))

//pvar $Y $X, lag(9) overid 
pvar $Y $X, lag(3) overid 
estimates store pvar_model


// save pvar_results_d_13.dta, replace
// use pvar_results_d_13.dta, clear
// estimates restore pvar_model

pvargranger

// 生成脉冲响应函数
pvarirf, impulse($X) response($Y) oirf step(10) mc(200) byoption(yrescale)
// byoption(yrescale)  save(irf_main) 

// 稳定性检验，单位根
pvarstable , graph

// 方差分解
pvarfevd

// 大城市和小城市
pvar $Y $X if big_city==1, lag(3) overid 
pvargranger
pvarirf, impulse($X) response($Y) oirf step(10) mc(200)

pvar $Y $X if big_city==0, lag(3) overid 
pvargranger
pvarirf, impulse($X) response($Y) oirf step(10) mc(200) byoption(yrescale)

// --------------  two-step 两步模型  --------------
varsoc $X if city_==1,maxlag(10)

pvar $X ,lag(8) overid

global pred_X
foreach `var' of varlist $X{
	predict pred_`var',`var'
	global pred_X "$pred_X pred_`var"
} 

reghdfe $Y $pred_X , a(city day) vce(cl city)



// 随时间相关关系图
local car co
twoway (line z_`var' month, yaxis(1) lcolor(blue))  (line z_pc_mobile month, yaxis(2) lcolor(red)) if city_==1,title("Time Series of `var' and pc_mobile") ytitle("Standardized `var'", axis(1)) ytitle("Standardized pc_mobile", axis(2)) xtitle("Month") legend(order(1 "z_`var'" 2 "z_pc_mobile"))
 
 // 体感温度与实际温度相关度0.9947，所以只选取一个，同样aqi pm10与pm2.5只选用pm2.5
