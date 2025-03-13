import os
import sys
import json
from sqlalchemy import create_engine, func
from sqlalchemy.orm import sessionmaker
from database_schema import (
    Base, Company, Domain, Tool, DnsRecord, HttpResponse,
    Vuln, VulnClass, Evidence
)


class Database:
    def __init__(self):
        self.db_uri = os.getenv('DB_URI')
        self.engine = create_engine(self.db_uri)
        Session = sessionmaker(bind=self.engine)
        self.session = Session()

    # ---------------------------
    # Company CRUD Operations
    # ---------------------------
    def add_company(self, name, program_page=None, program_platform=None, can_hack=None, visibility=None):
        company = Company(
            name=name,
            program_page=program_page,
            program_platform=program_platform,
            can_hack=can_hack,
            visibility=visibility
        )
        self.session.add(company)
        self.session.commit()
        return company

    def get_company(self, company_id):
        return self.session.query(Company).filter(Company.id == company_id).first()

    def get_all_companies(self, limit=100):
        return self.session.query(Company).limit(limit).all()

    def update_company(self, company_id, **kwargs):
        company = self.session.query(Company).filter(Company.id == company_id).first()
        if company:
            for key, value in kwargs.items():
                setattr(company, key, value)
            self.session.commit()
        return company

    def delete_company(self, company_id):
        company = self.session.query(Company).filter(Company.id == company_id).first()
        if company:
            self.session.delete(company)
            self.session.commit()

    # ---------------------------
    # Domain CRUD Operations
    # (Select/Get returns domains in random order)
    # ---------------------------
    def add_domain(self, name, level=None, type_=None, company_id=None, parent_domain_id=None,
                   skip_scans=None, last_passive_enumeration=None, last_active_enumeration=None,
                   last_probe=None, last_exploit=None):
        domain = Domain(
            name=name,
            level=level,
            type=type_,
            company_id=company_id,
            parent_domain_id=parent_domain_id,
            skip_scans=skip_scans,
            last_passive_enumeration=last_passive_enumeration,
            last_active_enumeration=last_active_enumeration,
            last_probe=last_probe,
            last_exploit=last_exploit
        )
        self.session.add(domain)
        self.session.commit()
        return domain

    def get_domain(self, domain_id):
        return self.session.query(Domain).filter(Domain.id == domain_id).first()

    def get_all_domains(self, limit=100):
        # Randomize the order of domains using PostgreSQL's random() function.
        return self.session.query(Domain).order_by(func.random()).limit(limit).all()

    def update_domain(self, domain_id, **kwargs):
        domain = self.session.query(Domain).filter(Domain.id == domain_id).first()
        if domain:
            for key, value in kwargs.items():
                setattr(domain, key, value)
            self.session.commit()
        return domain

    def delete_domain(self, domain_id):
        domain = self.session.query(Domain).filter(Domain.id == domain_id).first()
        if domain:
            self.session.delete(domain)
            self.session.commit()

    # ---------------------------
    # Tool CRUD Operations
    # ---------------------------
    def add_tool(self, name, type_=None):
        tool = Tool(name=name, type=type_)
        self.session.add(tool)
        self.session.commit()
        return tool

    def get_tool(self, tool_id):
        return self.session.query(Tool).filter(Tool.id == tool_id).first()

    def get_all_tools(self, limit=100):
        return self.session.query(Tool).limit(limit).all()

    def update_tool(self, tool_id, **kwargs):
        tool = self.session.query(Tool).filter(Tool.id == tool_id).first()
        if tool:
            for key, value in kwargs.items():
                setattr(tool, key, value)
            self.session.commit()
        return tool

    def delete_tool(self, tool_id):
        tool = self.session.query(Tool).filter(Tool.id == tool_id).first()
        if tool:
            self.session.delete(tool)
            self.session.commit()

    # ---------------------------
    # DnsRecord CRUD Operations
    # ---------------------------
    def add_dns_record(self, name, domain_id, type_=None, values=None):
        dns_record = DnsRecord(name=name, domain_id=domain_id, type=type_, values=values)
        self.session.add(dns_record)
        self.session.commit()
        return dns_record

    def get_dns_record(self, record_id):
        return self.session.query(DnsRecord).filter(DnsRecord.id == record_id).first()

    def get_all_dns_records(self, limit=100):
        return self.session.query(DnsRecord).limit(limit).all()

    def update_dns_record(self, record_id, **kwargs):
        record = self.session.query(DnsRecord).filter(DnsRecord.id == record_id).first()
        if record:
            for key, value in kwargs.items():
                setattr(record, key, value)
            self.session.commit()
        return record

    def delete_dns_record(self, record_id):
        record = self.session.query(DnsRecord).filter(DnsRecord.id == record_id).first()
        if record:
            self.session.delete(record)
            self.session.commit()

    # ---------------------------
    # HttpResponse CRUD Operations
    # ---------------------------
    def add_http_response(self, name, domain_id, url=None, scheme=None, method=None,
                          status_code=None, category=None, location=None,
                          content_type=None, content_length=None):
        http_response = HttpResponse(
            name=name,
            domain_id=domain_id,
            url=url,
            scheme=scheme,
            method=method,
            status_code=status_code,
            category=category,
            location=location,
            content_type=content_type,
            content_length=content_length
        )
        self.session.add(http_response)
        self.session.commit()
        return http_response

    def get_http_response(self, response_id):
        return self.session.query(HttpResponse).filter(HttpResponse.id == response_id).first()

    def get_all_http_responses(self, limit=100):
        return self.session.query(HttpResponse).limit(limit).all()

    # ---------------------------
    # Vuln CRUD Operations
    # ---------------------------
    def add_vuln(self, name, domain_id, title=None, vuln_class_id=None, description=None,
                 severity=None, references=None, notified=None):
        vuln = Vuln(
            name=name,
            domain_id=domain_id,
            title=title,
            vuln_class_id=vuln_class_id,
            description=description,
            severity=severity,
            references=references,
            notified=notified
        )
        self.session.add(vuln)
        self.session.commit()
        return vuln

    def get_vuln(self, vuln_id):
        return self.session.query(Vuln).filter(Vuln.id == vuln_id).first()

    def get_all_vulns(self, limit=100):
        return self.session.query(Vuln).limit(limit).all()

    # ---------------------------
    # VulnClass CRUD Operations
    # ---------------------------
    def add_vuln_class(self, name):
        vuln_class = VulnClass(name=name)
        self.session.add(vuln_class)
        self.session.commit()
        return vuln_class

    def get_vuln_class(self, vuln_class_id):
        return self.session.query(VulnClass).filter(VulnClass.id == vuln_class_id).first()

    def get_all_vuln_classes(self, limit=100):
        return self.session.query(VulnClass).limit(limit).all()

    # ---------------------------
    # Evidence CRUD Operations
    # ---------------------------
    def add_evidence(self, vuln_id, target=None, request=None, response=None):
        evidence = Evidence(
            vuln_id=vuln_id,
            target=target,
            request=request,
            response=response
        )
        self.session.add(evidence)
        self.session.commit()
        return evidence

    def get_evidence(self, evidence_id):
        return self.session.query(Evidence).filter(Evidence.id == evidence_id).first()

    def get_all_evidences(self, limit=100):
        return self.session.query(Evidence).limit(limit).all()

    # ---------------------------
    # Helper function when calling script via CLI
    # ---------------------------
    def _convert_arg(self, arg):
        """Converts CLI string arguments into appropriate data types."""
        if arg.lower() == 'true':
            return True
        elif arg.lower() == 'false':
            return False
        elif arg.isdigit():
            return int(arg)
        try:
            return float(arg)
        except ValueError:
            pass
        if ',' in arg:  # Convert comma-separated values into lists
            return arg.split(',')
        return arg  # Return as string if no conversion applies

def main():
    if len(sys.argv) < 2:
        print("Usage: python database.py <method_name> [args...]")
        sys.exit(1)

    method_name = sys.argv[1]
    db = Database()

    if not hasattr(db, method_name):
        print(json.dumps({"error": f"Method '{method_name}' not found"}))
        sys.exit(1)

    method = getattr(db, method_name)
    args = [db._convert_arg(arg) for arg in sys.argv[2:]]

    try:
        query_result = method(*args)
        if hasattr(query_result, '__iter__'):
            result = list()
            for row in query_result:
                result.append(row.__dict__)
        else:
            result = query_result.__dict__
        print(json.dumps({"result": result}, default=str))
    except Exception as e:
        print(json.dumps({"error": str(e)}))

if __name__ == "__main__":
    main()
