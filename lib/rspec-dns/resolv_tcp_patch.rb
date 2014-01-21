module ResolvTcpPatch
  def make_requester
    nameserver_port = @config.nameserver_port
    return Requester::TCP.new(*nameserver_port[0])
  end
end

