var GroupedVerticalBarChart = React.createClass({ 
  getInitialState: function() {
    var width_value = this.props.width || 400;
    return {
      width: width_value,
    };
  },
  getDefaultProps: function() {
    return {
      margin: {top: 20, right: 20, bottom: 30, left: 50},
      height: 250,
      bar_height: 20,
      bar_gap: 30,
      space_for_labels: 150,
      space_for_ticks: 30,
      space_for_legend: 100,
      fill_colour: '#03A9F4',
      colors: ["#9D1CB2", "#F6B500", "#47B04B", "#009788", "#A05D56", "#D0743C", "#FF8C00"],
      offcolor: "#434343",
    }
  },

  render: function() {
    var margin = this.props.margin,
      width = this.props.width - margin.left - margin.right -this.props.space_for_legend,
      height = this.props.height - margin.top - margin.bottom - this.props.space_for_labels;

    var chart = document.getElementById(this.props.chart_div);

    // set the range bands for the domain array (created further down the code)
    // rangeband will return the step for each band
    var x0 = d3.scale.ordinal()
      .rangeRoundBands([0, width], .1); // 10% padding

    var x1 = d3.scale.ordinal();

    var yi = d3.scale.linear()
      .range([0,height]);

    var y = d3.scale.linear()
      .range([height,0]);

    var colorFromRange = d3.scale.ordinal()
      .range(this.props.colors);

    var xAxis = d3.svg.axis()
      .scale(x0)
      .orient("bottom");

    var yAxis = d3.svg.axis()
      .scale(y)
      .orient("left")
      .tickFormat(d3.format(".2s"));

    var svg = d3.select(chart).append("svg")
      .attr("width", width + margin.left + margin.right + this.props.space_for_legend)
      .attr("height", height + margin.top + margin.bottom + this.props.space_for_labels)
      .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    all_data = this.props.data;

    // returns array of all data fieldnames (except site)
    var legendNames = d3.keys(all_data[0]).filter(function(key) 
                          { 
                            return key !== "site"; 
                          });

    // This bit must come AFTER the legendNames section above
    // creates new section in data with just data values
    all_data.forEach(function(d) 
      {   
        d.tests = legendNames.map(function(name) 
          { 
            return {name: name, value: +d[name]}; 
          });  
      });

    // create a domain range based on the site name (eg. ['AA','BB','CC'])
    x0.domain(all_data.map(function(d) { return d.site; }));

    x1.domain(legendNames).rangeRoundBands([0, x0.rangeBand()]);

    // return the y value scaled to fit the minima and maxima for the chart
    y.domain([0,d3.max(all_data, function(d) 
      { 
        return d3.max(d.tests, function(d) 
          { 
            return d.value; 
          }); 
      })
    ]);

    yi.domain([0,d3.max(all_data, function(d) 
      { 
        return d3.max(d.tests, function(d) 
          { 
            return d.value; 
          }); 
      })
    ]);

    // Horizontal Axis
    svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0,"+y(0)+")")
      .call(xAxis)
        .selectAll("text")
          .style("text-anchor", "end")
          .attr("dx", "-.8em")
          .attr("dy", ".15em")
          .attr("transform", function(d) { return "rotate(-45)" });

    // Vertical Axis
    svg.append("g")
      .attr("class", "y axis")
      .call(yAxis)
      .append("text")
        .attr("transform", "rotate(-90)")
        .attr("y", -50)   // note:  x/y are reversed due to the rotation (-x = move down)
        .attr("x", -70)
        .attr("dy", ".71em")  // align top
        .style("text-anchor", "end")
        .text("# tests");

    // Each block of graphs for a site
    var state = svg.selectAll(".state")
      .data(all_data)
      .enter()
        .append("g")
        .attr("class", "state")
        .attr("transform", function(d) { return "translate(" + x0(d.site) + ",0)"; });

    // all bars within site
    var barWidth = x1.rangeBand();
    state.selectAll("rect")
      .data(function(d) { return d.tests; })
      .enter()
        .append("rect")
          .attr("width", barWidth )
          .attr("x", function(d,i) { return barWidth*i; })
          .attr("y", function(d) { return y(d.value)-yi(0); })
          .attr("height", function(d) { return yi(d.value)-yi(0); })
          .style("fill", function(d) { return colorFromRange(d.name); });

      // legend
    var legend = svg.selectAll(".legend")
      .data(legendNames.slice().reverse())
      .enter()
        .append("g")
          .attr("class", "legend")
          .attr("transform", function(d, i) { return "translate(0,"+(i*25)+")"; });

    legend.append("rect")
      .attr("x", width - 1)
      .attr("width", 18)
      .attr("height", 18)
      .style("fill", colorFromRange);

    legend.append("text")
      .attr("x", width - 5)
      .attr("y", 9)
      .attr("dy", ".35em")
      .style("text-anchor", "end")
      //.attr("transform", "rotate(-45)")
      .text(function(d) { return d; });

    if (all_data.length == 0) {
      svg.append("text")
        .attr("x", this.props.width/2)
        .attr("y", this.props.height/2)
        .attr("dy", "-.7em")
        .attr("class", "chart-value-item")
        .style("text-anchor", "middle")
        .text("There is no data to display");
    }

    return (
      <div> </div>
    );
  }
});
