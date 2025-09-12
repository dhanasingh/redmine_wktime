$('<style>')
  .prop('type', 'text/css')
  .html(`
    #graph {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      padding: 8px;
      margin-right: -32px;
    }
    .icon-gravatar {
      flex: 0 0 calc(33.33% - 20px); /* 3 per row on large screens */
      max-width: calc(33.33% - 20px);
      padding: 10px 0;
      background: white;
      cursor: pointer;
      border-radius: 16px;
      display: flex;
      justify-content: center;
      align-items: center;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      transition: all 0.3s ease;
    }
    .icon-gravatar:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 16px rgba(0,0,0,0.2);
    }
    
    /* Tablet: 2 per row */
    @media (max-width: 1024px) {
      .icon-gravatar {
        flex: 0 0 calc(50% - 20px);
        max-width: calc(50% - 20px);
      }
    }

    /* Mobile: 1 per row */
    @media (max-width: 600px) {
      .icon-gravatar {
        flex: 0 0 100%;
        max-width: 100%;
      }
    }
  `)
  .appendTo('head');

function renderChart(url, path){
  let name = (path.split(".")).shift();
  name = (name.split("/")).pop();
  var width = screen.availWidth/3.25;
  var height = screen.availHeight/3.1;

  var div = '<div class="icon-gravatar" id="'+path+'">' +
              '<canvas id="'+name+'" width='+width+' height='+height+'></canvas>' +
            '</div>';

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
        // if (!chart.allTooltipsOnce) {
        //   if (easing !== 1)
        //     return;
        //   chart.allTooltipsOnce = true;
        // }
        // chart.options.tooltips.enabled = true;
        // Chart.helpers.each(chart.pluginTooltips, function (tooltip) {
        //   tooltip.initialize();
        //   tooltip.update();
        //   tooltip.pivot();
        //   tooltip.transition(easing).draw();
        // });
        chart.options.tooltips.enabled = true;
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

function createChart(data, name) {
  var isNonPiechart = (data["chart_type"] != "doughnut") ? true : false;
  var isPieChart = (data["chart_type"] == "doughnut") ? true : false;

  var bgcolor = isNonPiechart ? "rgba(0, 138, 230)" : [
    "#50b432", "#6384FF", "#F7464A", "#46BFBD", "#FDB45C", "#FEDCBA",
    "#ABCDEF", "#DDDDDD", "#ABCABC", "#949FB1", "#4D5360",
    "#bbbc49", "#d2b33f", "#e29f38", "#e77e31", "#e35129", "#d92120"
  ];

  var bordercolor = isNonPiechart ? "rgba(0, 138, 230)" : "rgba(255, 99, 132, 0.3)";

  var dataArr = [{
    label: data["legentTitle1"],
    fill: false,
    backgroundColor: (data["chart_type"] == "line") ? 'rgba(135, 206, 235, 0.3)' : bgcolor,
    borderColor: bordercolor,
    borderWidth: 3,
    barThickness: 13,
    data: data["data1"]
  }];

  if (data["legentTitle2"]) {
    dataArr.push({
      label: data["legentTitle2"],
      fill: false,
      backgroundColor: (data["chart_type"] == "line") ? 'rgba(255,0,0,0.2)' : "#E55C45",
      borderColor: "#E55C45",
      borderWidth: 3,
      barThickness: 13,
      data: data["data2"]
    });
  }

  if (data["legentTitle3"]) {
    dataArr.push({
      label: data["legentTitle3"],
      fill: false,
      backgroundColor: (data["chart_type"] == "line") ? 'rgba(0,0,255,0.2)' : "#50b432",
      borderColor: "#50b432",
      borderWidth: 3,
      barThickness: 13,
      data: data["data3"]
    });
  }

  var chartData = {
    labels: data["fields"],
    datasets: dataArr
  };

  new Chart(document.getElementById(name).getContext("2d"), {
    type: data["chart_type"],
    data: chartData,
    options: {
      plugins: {
        responsive: true,
        legend: { display: false },
        title: { display: true, text: data["graphName"] },
        tooltip: {
          backgroundColor: "rgb(0,0,0,0)",
          titleColor: 'rgb(0,0,0)',
          callbacks: {
            labelTextColor: function (context) {
              return 'rgb(0,0,0)';
            }
          }
        }
      },
      tooltips: {
        titleFontColor: "rgba(0, 0, 0, 1)",
        bodyFontColor: "rgba(0, 0, 0, 1)",
        backgroundColor: "rgba(0, 0, 0, 0)",
        bodyFontSize: 12
      },
      showAllTooltips: isPieChart,
      chartArea: { backgroundColor: "rgba(255, 255, 255, 0)" },
      scales: {
        yAxes: getAxes(false, "yTitle", isNonPiechart, data),
        xAxes: getAxes(true, "xTitle", isNonPiechart, data),
      },
      maintainAspectRatio: false,
      elements: {rectangle: {borderWidth: 5}}
    }
  });
}

function getAxes(autoSkip, label, isNonPiechart, data){
  return (
    {
      grid : {
        drawBorder: false,
        display : false
      },
      ticks: {
        display: isNonPiechart,
        autoSkip: autoSkip,
        maxRotation: 0,
        minRotation: 0,
        maxTicksLimit: label == "yTitle" ? 8 : 24,
        suggestedMax: label == "yTitle" ? (data.data1.at ? data.data1.at(-1)*1.10 : 0) : 0
      },
      title: {
        display: isNonPiechart,
        // labelString: data[label],
        fontColor: "#515151"
      }
    }
  )
}

function renderDetailReport(path, graphName){  
  
  // Choose base path based on 'path' content
  let basePath = "wkdashboard";
  if (path.includes("wkcrmdashboard")) {
    basePath = "wkcrmdashboard";
  } else if (path.includes("wkdashboard")) {
    basePath = "wkdashboard";
  }

  // Create the URL with the selected base
  let url = new URL(basePath + "/get_detail_report", window.location.origin);
  url.searchParams.append("gPath", path);
  const dashURL = new URL(window.location);
  dashURL.searchParams.forEach(function(value, key){
    if(["period", "project_id", "period_type", "user_id", "group_id"].includes(key)){
      url.searchParams.append(key, value);
    }
  });
  renderpopup(url, graphName)
}

function empDetailReport(type, issue_id, graphName){
  var url =  "/wkdashboard/get_detail_report?dashboard_type=Emp&type="+type+"&issue_id="+issue_id;
  renderpopup(url, graphName)
}

function invDetailReport(graphName, from, to) {
  var url = "/wkdashboard/get_inv_detail_report?dashboard_type=Inv&type=" + graphName + "&from=" + from + "&to=" + to;
  renderpopup(url, graphName);
}

function renderpopup(url, graphName){
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