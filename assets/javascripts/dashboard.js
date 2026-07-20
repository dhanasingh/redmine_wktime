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
    if (!data || data.error) {
      console.error("No chart data for " + name, data && data.error);
      return;
    }
    (window.chartjsReady || Promise.resolve()).then(function(){
      try {
        createChart(data, name);
        $("#"+name).click(function(){
          renderDetailReport(path, data.graphName);
        });
      } catch (e) {
        console.error("Failed to render chart " + name, e);
      }
    });
  }).fail(function(jqxhr, textStatus){
    console.error("Failed to load chart data for " + name + ": " + textStatus);
  });
}

function createChart(data, name) {
  var isNonPiechart = (data["chart_type"] != "doughnut");

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

  var options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
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
    elements: {bar: {borderWidth: 5}}
  };

  if (isNonPiechart) {
    options.scales = {
      y: getAxes(false, "yTitle", data),
      x: getAxes(true, "xTitle", data)
    };
  }

  new Chart(document.getElementById(name).getContext("2d"), {
    type: data["chart_type"],
    data: chartData,
    options: options
  });
}

function getAxes(autoSkip, label, data){
  var axis = {
    grid: {
      display: false
    },
    border: {
      display: false
    },
    ticks: {
      autoSkip: autoSkip,
      maxRotation: 0,
      minRotation: 0,
      maxTicksLimit: label == "yTitle" ? 8 : 24
    }
  };
  if (label == "yTitle" && data.data1 && data.data1.at) {
    axis.suggestedMax = data.data1.at(-1) * 1.10;
  }
  return axis;
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
