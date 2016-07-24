var TestResultRow = React.createClass({
  render: function() {
    var test = this.props.test_result;

    var assays = test.assays;
    var fillAssays = this.props.assaysColspan - assays.length;

    return (
    <tr data-href={'/test_results/' + test.uuid}>
      <td>{test.name}</td>

      {assays.map(function(assay) {
         return <td key={assay.condition} className="text-right"><AssayResult assay={assay}/></td>;
      })}
      { fillAssays > 0 ? <td colSpan={fillAssays}></td> : null }

      { this.props.showSites ? <td>{test.site ? test.site.name : null}</td> : null }
      { this.props.showDevices ? <td>{test.device ? test.device.name : null}</td> : null }
      { this.props.showDevices ? <td>{test.device ? test.device.serial_number : null}</td> : null }
      <td>{test.sample_entity_ids}</td>
      <td>{test.type}</td>
      <td>{test.status}</td>
      <td>{test.error_code}</td>
      <td>{test.start_time}</td>
      <td>{test.end_time}</td>
    </tr>);
  }
});

var TestResultsList = React.createClass({
  getDefaultProps: function() {
    return {
      title: "Tests",
      titleClassName: "",
      downloadCsvPath: null,
      allowSorting: true,
      orderBy: "site.name",
      showSites: true,
      showDevices: true
    }
  },

  componentDidMount: function() {
    $("table").resizableColumns({store: window.store});
  },

  render: function() {
    var sortableHeader = function (title, field) {
      if (this.props.allowSorting) {
        return <SortableColumnHeader title={title} field={field} orderBy={this.props.orderBy} />
      } else {
        return <th>{title}</th>;
      }
    }.bind(this);

    var totalAssaysColCount = _.reduce(this.props.testResults, function(m, test) {
      return Math.max(m, test.assays.length);
    }, 1);

    return (
      <table className="table" cellPadding="0" cellSpacing="0" data-resizable-columns-id="test-results-table">
        <thead>
          <tr>
            {sortableHeader("Test", "test.name")}
            <th data-resizable-column-id="results" colSpan={totalAssaysColCount} className="text-right">Results</th>
            { this.props.showSites ? sortableHeader("Site", "site.name") : null }
            { this.props.showDevices ? sortableHeader("Device name", "device.name") : null }
            { this.props.showDevices ? sortableHeader("Device serial number", "device.serial_number") : null }
            {sortableHeader("Sample ID", "sample.id")}
            {sortableHeader("Type", "test.type")}
            {sortableHeader("Status", "test.status")}
            {sortableHeader("Error code", "test.error_code")}
            {sortableHeader("Start time", "test.start_time")}
            {sortableHeader("End time", "test.end_time")}
          </tr>
        </thead>
        <tbody>
          {this.props.testResults.map(function(test_result) {
             return <TestResultRow key={test_result.uuid} test_result={test_result}
              showSites={this.props.showSites} showDevices={this.props.showDevices}
              assaysColspan={totalAssaysColCount} />;
          }.bind(this))}
        </tbody>
      </table>
    );
  }
});

var TestResultsIndexTable = React.createClass({
  render: function() {
    return <TestResultsList testResults={this.props.tests}
              titleClassName="table-title"
              allowSorting={true} orderBy={this.props.orderBy}
              showSites={this.props.showSites} showDevices={this.props.showDevices} />
  }
});
