var PolicyItem = React.createClass({
  render: function() {
    var statement = this.props.statement;
    if(statement.resourceType == null) {
      return (
        <div>
          <div className="resource-type">New Policy</div>
          <div className="description">Type, resource, and actions are not defined yet</div>
        </div>
      );
    } else {
      var withSubsites = "";
      if(statement.includeSubsites) {
        if(statement.resourceType == "site") {
          withSubsites = " and subsites";
        } else {
          withSubsites = " at site and subsites";
        }
      }
      return (
        <div>
          <div className="resource-type">{statement.resourceType}{withSubsites}</div>
          <div className="description">Device, aca, algo esto</div>
        </div>
      );
    }
  },

});
