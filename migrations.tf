moved {
  from = aws_eip.fortigate_isp1["hub1"]
  to   = aws_eip.internet_router["hub1_isp1"]
}

moved {
  from = aws_eip.fortigate_isp2["hub1"]
  to   = aws_eip.internet_router["hub1_isp2"]
}

moved {
  from = aws_eip.fortigate_isp1["hub2"]
  to   = aws_eip.internet_router["hub2_isp1"]
}

moved {
  from = aws_eip.fortigate_isp2["hub2"]
  to   = aws_eip.internet_router["hub2_isp2"]
}

moved {
  from = aws_eip.fortigate_isp1["branch1"]
  to   = aws_eip.internet_router["branch1_isp1"]
}

moved {
  from = aws_eip.fortigate_isp2["branch1"]
  to   = aws_eip.internet_router["branch1_isp2"]
}
