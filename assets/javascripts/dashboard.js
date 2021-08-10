function renderChart(url, path){
  let name = (path.split(".")).shift();
  name = (name.split("/")).pop();
	var div = '<div class="icon-gravatar" style="margin-left: 40px; cursor: pointer;" id="'+path+'"><canvas id="'+name+'" width="330" height="240" ></canvas></div>';
	$("#graph").append(div);
  let params = (new URLSearchParams(window.location.search)).toString();
  url += "&"+params;

  $.getJSON(url, function(data){
    createChart(data, name);
    $("#"+name).click(function(){
      renderDetailReport(path, data.graphName);
    });
  });
}

function registerChart(){
  Chart.pluginService.register({
    beforeRender: function (chart) {
      if (chart.config.options.showAllTooltips) {
        chart.pluginTooltips = [];
        chart.config.data.datasets.forEach(function (dataset, i) {
          chart.getDatasetMeta(i).data.forEach(function (sector, j) {
            chart.pluginTooltips.push(new Chart.Tooltip({
              _chart: chart.chart,
              _chartInstance: chart,
              _data: chart.data,
              _options: chart.options.tooltips,
              _active: [sector]
            }, chart));
          });
        });
        chart.options.tooltips.enabled = false;
      }
    },
    afterDraw: function (chart, easing) {
      if (chart.config.options.showAllTooltips) {
        if (!chart.allTooltipsOnce) {
          if (easing !== 1)
            return;
          chart.allTooltipsOnce = true;
        }
        chart.options.tooltips.enabled = true;
        Chart.helpers.each(chart.pluginTooltips, function (tooltip) {
          tooltip.initialize();
          tooltip.update();
          tooltip.pivot();
          tooltip.transition(easing).draw();
        });
        chart.options.tooltips.enabled = false;
      }
    },
    beforeDraw: function (chart, easing) {
      if (chart.config.options.chartArea && chart.config.options.chartArea.backgroundColor) {
        var ctx = chart.chart.ctx;
        var chartArea = chart.chartArea;
        ctx.save();
        ctx.fillStyle = chart.config.options.chartArea.backgroundColor;
        ctx.fillRect(chartArea.left, chartArea.top, chartArea.right - chartArea.left, chartArea.bottom - chartArea.top);
        ctx.restore();
      }
    }
  });
}

function createChart(data, name){
  var isNonPiechart = (data["chart_type"] != "pie") ? true : false;
  var isPieChart = (data["chart_type"] == "pie") ? true : false;
  var bgcolor = isNonPiechart ? "rgba(255, 99, 132, 1)" : [ "#FF6384", "#84FF63","#8463FF","#6384FF","#F7464A", "#46BFBD", "#FDB45C", "#FEDCBA","#ABCDEF", "#DDDDDD", "#ABCABC", "#949FB1", "#4D5360"];
  var bordercolor = isNonPiechart ? "rgba(255, 99, 132, 1)" : "rgba(255, 99, 132, 0.3)";

  var dataArr = [{
    label: data["legentTitle1"],
    fill: false,
    backgroundColor: bgcolor,
    borderColor: bordercolor,
    borderWidth: 3,
    data: data["data1"]
    }];

  if(data["legentTitle2"]){
    dataArr.push({
      label: data["legentTitle2"],
      fill: false,
      backgroundColor: "rgba(54, 162, 235, 0.7)",
      borderColor: "rgb(54, 162, 235)",
      data: data["data2"]
    });
  }
  var chartData = {labels: data["fields"], datasets: dataArr};

  new Chart(document.getElementById(name).getContext("2d"), {
    type: data["chart_type"],
    data: chartData,
    options: {
      tooltips: {
        titleFontColor: "rgba(0, 0, 0, 1)",
        bodyFontColor: "rgba(0, 0, 0, 1)",
        backgroundColor: "rgba(0, 0, 0, 0)",
        bodyFontSize: 12
      },
      showAllTooltips: isPieChart,
      chartArea: {backgroundColor: "rgba(240, 240, 240, 1)"},
      scales: {
        yAxes: getAxes(false, "yTitle", isNonPiechart, data),
        xAxes: getAxes(true, "xTitle", isNonPiechart, data),
      },
      elements: {rectangle: {borderWidth: 2}},
      responsive: true,
      legend: {display: isNonPiechart, position: "bottom"},
      title: {fontColor: "#000", display: true, text: data["graphName"]}
    }
  });
}

function getAxes(autoSkip, label, isNonPiechart, data){
  return (
    [{
      gridLines : {
        drawBorder: isNonPiechart,
        display : isNonPiechart
      },
      ticks: {
        display: isNonPiechart,
        autoSkip: autoSkip,
        maxRotation: 0,
        minRotation: 0
      },
      scaleLabel: {
        display: isNonPiechart,
        labelString: data[label],
        fontColor: "#ff0000"
      }
    }]
  )
}

function renderDetailReport(path, graphName){
  let url = new URL("wkdashboard/getDetailReport", window.location.origin);
  url.searchParams.append("gPath", path);
  const dashURL = new URL(window.location);
  dashURL.searchParams.forEach(function(value, key){
    if(["period", "project_id", "period_type", "user_id", "group_id"].includes(key)){
      url.searchParams.append(key, value);
    }
  });

  $.getJSON(url, function(data){
    renderData(data);
    $("#dialog" ).dialog({
      modal: true,
      title: graphName,
      width: "40%",
      height: $(window).height() - 150,
    });
  });
}